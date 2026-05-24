import Foundation
import CoreBluetooth

final class BLEManager: NSObject, ObservableObject {
    @Published private(set) var discoveredDevices: [BLEDevice] = []
    @Published private(set) var connectedDevice: BLEDevice?

    private let errorLogger: ErrorLogger
    private let config: BLEProtocol.Config

    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!

    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var transferCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var connectedCentral: CBCentral?
    private var isNotifyReady = false

    private var mutableTransferCharacteristic: CBMutableCharacteristic?
    private var mutableNotifyCharacteristic: CBMutableCharacteristic?

    private let protocolServiceUUID: CBUUID
    private let transferCharacteristicUUID: CBUUID
    private let notifyCharacteristicUUID: CBUUID

    private(set) var lastTransferTelemetry: BLETransferTelemetry?

    private var responsePayloadProvider: (Data) -> Data = { inbound in inbound }

    private var ackedIndexes: Set<UInt32> = []
    private var inboundBuffer = Data()
    private var inboundExpectedChunks: UInt32?
    private var inboundReceivedChunks: UInt32 = 0
    private var inboundCompletedPayload: Data?

    private var peripheralInboundBuffer = Data()
    private var peripheralInboundExpectedChunks: UInt32?
    private var peripheralInboundReceivedChunks: UInt32 = 0
    private var isPeripheralServiceAdded = false
    private var isAdvertising = false
    private var pendingPeripheralNotifications: [Data] = []

    private var currentJitterPercent: Double
    private let stateLock = NSLock()

    init(errorLogger: ErrorLogger, config: BLEProtocol.Config = .default) {
        self.errorLogger = errorLogger
        self.config = config
        self.protocolServiceUUID = CBUUID(string: config.serviceUUID)
        self.transferCharacteristicUUID = CBUUID(string: config.transferCharacteristicUUID)
        self.notifyCharacteristicUUID = CBUUID(string: config.notifyCharacteristicUUID)
        self.currentJitterPercent = config.ackRetryJitterPercent
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func setResponsePayloadProvider(_ provider: @escaping (Data) -> Data) {
        responsePayloadProvider = provider
    }

    func startScan() {
        guard centralManager.state == .poweredOn else {
            discoveredDevices = []
            return
        }
        discoveredDevices = []
        peripheralsByID.removeAll()
        centralManager.scanForPeripherals(
            withServices: [protocolServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScan() {
        centralManager.stopScan()
    }

    func connect(_ device: BLEDevice) {
        guard centralManager.state == .poweredOn else {
            errorLogger.log("Unable to connect. Bluetooth is not powered on")
            return
        }
        guard let peripheral = peripheralsByID[device.id] else {
            errorLogger.log("Unable to connect. Peripheral \(device.name) not found")
            return
        }
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let connectedPeripheral {
            centralManager.cancelPeripheralConnection(connectedPeripheral)
        } else {
            connectedDevice = nil
        }
    }

    func transfer(payload: Data) async throws -> Data {
        guard connectedDevice != nil else {
            throw BLETransferError.deviceNotConnected
        }

        let notifyReady = await waitForNotifyReady(timeoutNs: 2_000_000_000)
        guard notifyReady else {
            throw BLETransferError.deviceNotConnected
        }

        resetInboundState()
        let chunks = BLEProtocol.chunk(payload, size: config.chunkSize)
        var metrics = TransferMetricsAccumulator(logicalPacketCount: chunks.count + 2)

        guard
            let peripheral = connectedPeripheral,
            let tx = transferCharacteristic
        else {
            throw BLETransferError.deviceNotConnected
        }

        try await sendWithRetry(.start, index: UInt32(chunks.count), payload: Data(), fallbackErrorIndex: Int(BLEProtocol.controlStartIndex), peripheral: peripheral, characteristic: tx, metrics: &metrics)

        for (index, chunk) in chunks.enumerated() {
            try await sendWithRetry(.chunk, index: UInt32(index), payload: chunk, fallbackErrorIndex: index, peripheral: peripheral, characteristic: tx, metrics: &metrics)
        }

        try await sendWithRetry(.end, index: BLEProtocol.controlEndIndex, payload: Data(), fallbackErrorIndex: Int(BLEProtocol.controlEndIndex), peripheral: peripheral, characteristic: tx, metrics: &metrics)

        if let response = await waitForInboundPayload(timeoutNs: config.responseTimeoutNs) {
            lastTransferTelemetry = BLEProtocol.telemetry(
                logicalPacketCount: metrics.logicalPacketCount,
                retryCount: metrics.retryCount,
                timeoutCount: metrics.timeoutCount,
                totalRetryDelayNs: metrics.totalRetryDelayNs,
                maxRetryDelayNs: metrics.maxRetryDelayNs,
                jitterPercent: currentJitterPercent
            )
            return response
        }

        lastTransferTelemetry = BLEProtocol.telemetry(
            logicalPacketCount: metrics.logicalPacketCount,
            retryCount: metrics.retryCount,
            timeoutCount: metrics.timeoutCount,
            totalRetryDelayNs: metrics.totalRetryDelayNs,
            maxRetryDelayNs: metrics.maxRetryDelayNs,
            jitterPercent: currentJitterPercent
        )
        throw BLETransferError.responseTimeout
    }

    private func sendWithRetry(
        _ type: BLEProtocol.PacketType,
        index: UInt32,
        payload: Data,
        fallbackErrorIndex: Int,
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        metrics: inout TransferMetricsAccumulator
    ) async throws {
        let attempts = BLEProtocol.totalAttempts(maxRetries: config.maxAckRetries)
        for attempt in 1...attempts {
            let baseDelayNs = BLEProtocol.retryDelay(
                attempt: attempt,
                baseDelayNs: config.ackRetryBaseDelayNs,
                maxDelayNs: config.ackRetryMaxDelayNs
            )
            let randomUnit = Double.random(in: 0...1)
            let jitterPercent = readCurrentJitterPercent()
            let delayNs = BLEProtocol.jitteredDelay(
                delayNs: baseDelayNs,
                jitterPercent: jitterPercent,
                randomUnit: randomUnit
            )
            if delayNs > 0 {
                try await Task.sleep(nanoseconds: delayNs)
                metrics.totalRetryDelayNs += delayNs
                metrics.maxRetryDelayNs = max(metrics.maxRetryDelayNs, delayNs)
            }
            try await writePacket(type, index: index, payload: payload, peripheral: peripheral, characteristic: characteristic)
            let acknowledged = await waitForAck(for: index, timeoutNs: config.ackTimeoutNs)
            if acknowledged {
                updateJitterAfterSuccess()
                metrics.retryCount += max(0, attempt - 1)
                metrics.timeoutCount += metrics.pendingTimeouts
                metrics.pendingTimeouts = 0
                return
            }
            metrics.pendingTimeouts += 1
            updateJitterAfterTimeout()
        }
        metrics.retryCount += max(0, attempts - 1)
        metrics.timeoutCount += metrics.pendingTimeouts + 1
        metrics.pendingTimeouts = 0
        throw BLETransferError.ackTimeout(fallbackErrorIndex)
    }

    private func readCurrentJitterPercent() -> Double {
        stateLock.lock()
        let value = currentJitterPercent
        stateLock.unlock()
        return value
    }

    private func updateJitterAfterTimeout() {
        stateLock.lock()
        currentJitterPercent = BLEProtocol.nextJitterAfterTimeout(
            current: currentJitterPercent,
            minPercent: config.ackAdaptiveJitterMinPercent,
            maxPercent: config.ackAdaptiveJitterMaxPercent,
            stepUpPercent: config.ackAdaptiveJitterStepUpPercent
        )
        stateLock.unlock()
    }

    private func updateJitterAfterSuccess() {
        stateLock.lock()
        currentJitterPercent = BLEProtocol.nextJitterAfterSuccess(
            current: currentJitterPercent,
            minPercent: config.ackAdaptiveJitterMinPercent,
            maxPercent: config.ackAdaptiveJitterMaxPercent,
            stepDownPercent: config.ackAdaptiveJitterStepDownPercent
        )
        stateLock.unlock()
    }

    private func writePacket(
        _ type: BLEProtocol.PacketType,
        index: UInt32,
        payload: Data,
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic
    ) async throws {
        let packet = BLEProtocol.encode(type: type, index: index, payload: payload)
        peripheral.writeValue(packet, for: characteristic, type: .withResponse)
        try await Task.sleep(nanoseconds: 2_000_000)
    }

    private func waitForAck(for index: UInt32, timeoutNs: UInt64) async -> Bool {
        let stepNs: UInt64 = 20_000_000
        var elapsed: UInt64 = 0
        while elapsed < timeoutNs {
            stateLock.lock()
            let acknowledged = ackedIndexes.remove(index) != nil
            stateLock.unlock()
            if acknowledged {
                return true
            }
            do {
                try await Task.sleep(nanoseconds: stepNs)
            } catch {
                return false
            }
            elapsed += stepNs
        }
        return false
    }

    private func waitForInboundPayload(timeoutNs: UInt64) async -> Data? {
        let stepNs: UInt64 = 20_000_000
        var elapsed: UInt64 = 0
        while elapsed < timeoutNs {
            stateLock.lock()
            let payload = inboundCompletedPayload
            stateLock.unlock()
            if let payload {
                return payload
            }
            do {
                try await Task.sleep(nanoseconds: stepNs)
            } catch {
                return nil
            }
            elapsed += stepNs
        }
        return nil
    }

    private func waitForNotifyReady(timeoutNs: UInt64) async -> Bool {
        let stepNs: UInt64 = 20_000_000
        var elapsed: UInt64 = 0
        while elapsed < timeoutNs {
            stateLock.lock()
            let ready = isNotifyReady && notifyCharacteristic != nil && transferCharacteristic != nil
            stateLock.unlock()
            if ready {
                return true
            }
            do {
                try await Task.sleep(nanoseconds: stepNs)
            } catch {
                return false
            }
            elapsed += stepNs
        }
        return false
    }

    private func resetInboundState() {
        stateLock.lock()
        ackedIndexes.removeAll()
        inboundBuffer = Data()
        inboundExpectedChunks = nil
        inboundReceivedChunks = 0
        inboundCompletedPayload = nil
        currentJitterPercent = config.ackRetryJitterPercent
        lastTransferTelemetry = nil
        stateLock.unlock()
    }

    private func markAck(index: UInt32) {
        stateLock.lock()
        ackedIndexes.insert(index)
        stateLock.unlock()
    }

    private func handleCentralIncomingPacket(_ packet: BLEProtocol.Packet, peripheral: CBPeripheral) {
        switch packet.type {
        case .ack:
            markAck(index: packet.index)
        case .start:
            stateLock.lock()
            inboundExpectedChunks = packet.index
            inboundReceivedChunks = 0
            inboundBuffer = Data()
            inboundCompletedPayload = nil
            stateLock.unlock()
            sendAckAsCentral(index: packet.index, peripheral: peripheral)
        case .chunk:
            stateLock.lock()
            inboundBuffer.append(packet.payload)
            inboundReceivedChunks += 1
            stateLock.unlock()
            sendAckAsCentral(index: packet.index, peripheral: peripheral)
        case .end:
            stateLock.lock()
            let expected = inboundExpectedChunks
            let received = inboundReceivedChunks
            if expected == nil || expected == received {
                inboundCompletedPayload = inboundBuffer
            }
            stateLock.unlock()
            sendAckAsCentral(index: packet.index, peripheral: peripheral)
        }
    }

    private func sendAckAsCentral(index: UInt32, peripheral: CBPeripheral) {
        guard let tx = transferCharacteristic else { return }
        let ack = BLEProtocol.encode(type: .ack, index: index)
        peripheral.writeValue(ack, for: tx, type: .withResponse)
    }

    private func setupPeripheralServiceIfNeeded() {
        guard peripheralManager.state == .poweredOn else { return }
        guard mutableTransferCharacteristic == nil, mutableNotifyCharacteristic == nil else { return }

        let transfer = CBMutableCharacteristic(
            type: transferCharacteristicUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        let notify = CBMutableCharacteristic(
            type: notifyCharacteristicUUID,
            properties: [.notify, .read],
            value: nil,
            permissions: [.readable]
        )

        let service = CBMutableService(type: protocolServiceUUID, primary: true)
        service.characteristics = [transfer, notify]

        peripheralManager.removeAllServices()
        isPeripheralServiceAdded = false
        peripheralManager.add(service)

        mutableTransferCharacteristic = transfer
        mutableNotifyCharacteristic = notify
    }

    private func advertisingName() -> String {
        // Keep it short so Service UUID remains in the advertising payload.
        return "SFinance-iOS"
    }

    private func startAdvertisingNow() {
        guard peripheralManager.state == .poweredOn else { return }
        guard isPeripheralServiceAdded else { return }
        peripheralManager.stopAdvertising()
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [protocolServiceUUID],
            CBAdvertisementDataLocalNameKey: advertisingName()
        ])
        isAdvertising = true
        errorLogger.log("BLE advertising started")
    }

    private func startAdvertisingIfPossible() {
        guard peripheralManager.state == .poweredOn else { return }
        setupPeripheralServiceIfNeeded()
        startAdvertisingNow()
    }

    private func resetPeripheralInboundState() {
        peripheralInboundExpectedChunks = nil
        peripheralInboundReceivedChunks = 0
        peripheralInboundBuffer = Data()
    }

    private func sendPacketAsPeripheral(_ packet: Data) {
        pendingPeripheralNotifications.append(packet)
        flushPeripheralNotificationQueue()
    }

    private func flushPeripheralNotificationQueue() {
        guard let notify = mutableNotifyCharacteristic else { return }

        while let next = pendingPeripheralNotifications.first {
            let sent = peripheralManager.updateValue(next, for: notify, onSubscribedCentrals: nil)
            if !sent {
                return
            }
            pendingPeripheralNotifications.removeFirst()
        }
    }

    private func sendAckAsPeripheral(index: UInt32) {
        let ack = BLEProtocol.encode(type: .ack, index: index)
        sendPacketAsPeripheral(ack)
    }

    private func sendResponseAsPeripheral(_ payload: Data) {
        let chunks = BLEProtocol.chunk(payload, size: config.chunkSize)
        sendPacketAsPeripheral(BLEProtocol.encode(type: .start, index: UInt32(chunks.count), payload: Data()))
        for (index, chunk) in chunks.enumerated() {
            sendPacketAsPeripheral(BLEProtocol.encode(type: .chunk, index: UInt32(index), payload: chunk))
        }
        sendPacketAsPeripheral(BLEProtocol.encode(type: .end, index: BLEProtocol.controlEndIndex, payload: Data()))
    }

    private func handlePeripheralIncomingPacket(_ packet: BLEProtocol.Packet) {
        switch packet.type {
        case .ack:
            return
        case .start:
            peripheralInboundExpectedChunks = packet.index
            peripheralInboundReceivedChunks = 0
            peripheralInboundBuffer = Data()
            sendAckAsPeripheral(index: packet.index)
        case .chunk:
            peripheralInboundBuffer.append(packet.payload)
            peripheralInboundReceivedChunks += 1
            sendAckAsPeripheral(index: packet.index)
        case .end:
            sendAckAsPeripheral(index: packet.index)
            let expected = peripheralInboundExpectedChunks
            guard expected == nil || expected == peripheralInboundReceivedChunks else { return }
            let responsePayload = responsePayloadProvider(peripheralInboundBuffer)
            sendResponseAsPeripheral(responsePayload)
            resetPeripheralInboundState()
        }
    }

    private struct TransferMetricsAccumulator {
        var logicalPacketCount: Int
        var retryCount: Int = 0
        var timeoutCount: Int = 0
        var pendingTimeouts: Int = 0
        var totalRetryDelayNs: UInt64 = 0
        var maxRetryDelayNs: UInt64 = 0
    }
}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startAdvertisingIfPossible()
        } else {
            discoveredDevices = []
            connectedDevice = nil
            errorLogger.log("Bluetooth is not powered on")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let device = BLEDevice(id: peripheral.identifier, name: peripheral.name ?? "Unknown Device", signalStrength: RSSI.intValue)
        peripheralsByID[device.id] = peripheral
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        stateLock.lock()
        isNotifyReady = false
        stateLock.unlock()
        peripheral.discoverServices([protocolServiceUUID])
        connectedDevice = BLEDevice(id: peripheral.identifier, name: peripheral.name ?? "Unknown Device", signalStrength: -50)
        errorLogger.log("Connected to \(connectedDevice?.name ?? "Unknown")")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error {
            errorLogger.log(error, context: "BLE connect")
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
            transferCharacteristic = nil
            notifyCharacteristic = nil
            stateLock.lock()
            isNotifyReady = false
            stateLock.unlock()
            connectedDevice = nil
            resetInboundState()
        }
        if let error {
            errorLogger.log(error, context: "BLE disconnect")
        }
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            errorLogger.log(error, context: "BLE discover services")
            return
        }

        peripheral.services?.forEach { service in
            if service.uuid == protocolServiceUUID {
                peripheral.discoverCharacteristics([transferCharacteristicUUID, notifyCharacteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            errorLogger.log(error, context: "BLE discover characteristics")
            return
        }

        service.characteristics?.forEach { characteristic in
            if characteristic.uuid == transferCharacteristicUUID {
                transferCharacteristic = characteristic
            }
            if characteristic.uuid == notifyCharacteristicUUID {
                notifyCharacteristic = characteristic
                stateLock.lock()
                isNotifyReady = false
                stateLock.unlock()
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            errorLogger.log(error, context: "BLE notify state")
            stateLock.lock()
            isNotifyReady = false
            stateLock.unlock()
            return
        }

        guard characteristic.uuid == notifyCharacteristicUUID else { return }
        stateLock.lock()
        isNotifyReady = characteristic.isNotifying
        stateLock.unlock()
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        if invalidatedServices.contains(where: { $0.uuid == protocolServiceUUID }) {
            transferCharacteristic = nil
            notifyCharacteristic = nil
            stateLock.lock()
            isNotifyReady = false
            stateLock.unlock()
            peripheral.discoverServices([protocolServiceUUID])
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            errorLogger.log(error, context: "BLE receive")
            return
        }

        guard let data = characteristic.value else { return }
        guard let packet = BLEProtocol.decode(data) else {
            errorLogger.log(BLETransferError.invalidPacket, context: "BLE decode")
            return
        }

        handleCentralIncomingPacket(packet, peripheral: peripheral)
    }
}

extension BLEManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            startAdvertisingIfPossible()
        } else {
            peripheral.stopAdvertising()
            isAdvertising = false
            isPeripheralServiceAdded = false
            mutableTransferCharacteristic = nil
            mutableNotifyCharacteristic = nil
            pendingPeripheralNotifications.removeAll()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            errorLogger.log(error, context: "BLE didAdd service")
            isPeripheralServiceAdded = false
            return
        }
        isPeripheralServiceAdded = true
        startAdvertisingNow()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            isAdvertising = false
            errorLogger.log(error, context: "BLE start advertising")
            return
        }
        isAdvertising = true
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        connectedCentral = central
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if connectedCentral?.identifier == central.identifier {
            connectedCentral = nil
            pendingPeripheralNotifications.removeAll()
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        flushPeripheralNotificationQueue()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard request.characteristic.uuid == transferCharacteristicUUID else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                continue
            }
            guard let value = request.value, let packet = BLEProtocol.decode(value) else {
                peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
                continue
            }

            handlePeripheralIncomingPacket(packet)
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
