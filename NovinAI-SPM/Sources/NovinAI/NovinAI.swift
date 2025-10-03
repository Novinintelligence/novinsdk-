import Foundation
#if canImport(Python)
import Python
#endif

public enum NovinAIError: Error {
    case invalidPayload
    case unexpectedResponse
    case pythonUnavailable
}

public final class NovinAI {
    private var isInitialised = false

    public init() { _ = bootstrapPython() }

    @discardableResult
    private func bootstrapPython() -> Bool {
        guard !isInitialised else { return true }
        #if canImport(Python)
        PythonLibrary.useVersion(3, 10)
        let sys = Python.import("sys")
        if let rp = Bundle.main.resourcePath {
            sys.path.append(rp + "/ProtectedPython")
            // Include vendored site-packages we installed
            sys.path.append(rp + "/Python.xcframework/ios-arm64/lib/python3.13/site-packages")
        }
        #else
        return false
        #endif
        isInitialised = true
        return true
    }

    public func process(json data: Data) throws -> [String: Any] {
        guard let jsonString = String(data: data, encoding: .utf8) else { throw NovinAIError.invalidPayload }
        #if canImport(Python)
        _ = bootstrapPython()
        let novin = Python.import("novin_ai")
        let result = novin.process_request(jsonString)
        return try convert(dictionary: result)
        #else
        throw NovinAIError.pythonUnavailable
        #endif
    }

    #if canImport(Python)
    private func convert(dictionary pythonDict: PythonObject) throws -> [String: Any] {
        guard Python.builtins.isinstance(pythonDict, Python.dict) == true else { throw NovinAIError.unexpectedResponse }
        var swiftDict: [String: Any] = [:]
        for (k, v) in pythonDict {
            let key = String(describing: k)
            switch true {
            case Python.builtins.isinstance(v, Python.bool) == true:   swiftDict[key] = Bool(v) ?? false
            case Python.builtins.isinstance(v, Python.int) == true:    swiftDict[key] = Int(v) ?? 0
            case Python.builtins.isinstance(v, Python.float) == true:  swiftDict[key] = Double(v) ?? 0.0
            case Python.builtins.isinstance(v, Python.dict) == true:   swiftDict[key] = try convert(dictionary: v)
            case Python.builtins.isinstance(v, Python.list) == true:   swiftDict[key] = v.compactMap { String($0) }
            default: swiftDict[key] = String(describing: v)
            }
        }
        return swiftDict
    }
    #endif
}
