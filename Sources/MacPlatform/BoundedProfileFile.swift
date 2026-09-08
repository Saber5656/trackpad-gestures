import Foundation
import Darwin

public enum BoundedProfileFile {
    public static let maximumBytes=256*1024
    public static func read(_ url:URL) throws -> Data {
        // Open once, refuse symlinks/special files and never read the full untrusted stream.
        let descriptor=open(url.path,O_RDONLY | O_NONBLOCK | O_NOFOLLOW)
        guard descriptor >= 0 else { throw ActionFailure.invalid }
        let handle=FileHandle(fileDescriptor:descriptor,closeOnDealloc:true)
        defer { try? handle.close() }
        var metadata=stat()
        guard fstat(descriptor,&metadata)==0, metadata.st_mode & S_IFMT == S_IFREG else { throw ActionFailure.invalid }
        let data=try handle.read(upToCount:maximumBytes+1) ?? Data()
        guard data.count <= maximumBytes else { throw ActionFailure.invalid }
        return data
    }
}
