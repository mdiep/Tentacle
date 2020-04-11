import Foundation

extension Result {
    var value: Success? {
        switch self {
        case .success(let success): return success
        case .failure: return nil
        }
    }
    
    var error: Failure? {
        switch self {
        case .success: return nil
        case .failure(let error): return error
        }
    }
}
