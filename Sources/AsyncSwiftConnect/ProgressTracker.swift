//
//  ProgressTracker.swift
//  AsyncSwiftConnect
//
//  Created by MK-Mini on 11/9/2568 BE.
//

actor ProgressTracker {
    private var handlers: [Int: ((Double) -> Void)] = [:]
    
    func register(taskId: Int?, handler: @escaping (Double) -> Void) {
        guard let taskId = taskId
        else { return }
        
        handlers[taskId] = handler
    }
    
    func getHandler(taskId: Int) -> ((Double) -> Void)? {
        return handlers[taskId]
    }
    
    func remove(taskId: Int?) {
        guard let taskId = taskId
        else { return }
        
        handlers.removeValue(forKey: taskId)
    }
    
    func updateProgress(taskId: Int, progress: Double) {
        if let handler = handlers[taskId] {
            handler(progress)
        }
    }
}
