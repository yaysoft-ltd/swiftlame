//
//  Copyright © 2023 Hidden Spectrum, LLC. All rights reserved.
//

import Foundation


public enum SwiftLameError: Error {
    case couldNotCreateAudioPCMBuffer
    case couldNotCreateOutputStreamTo(url: URL)
    case couldNotGetRawOutputBufferPointerBaseAddress
    case couldNotReadChannelDataFromPCMBuffer
    /// LAME reported an error (negative length) or the file took fewer bytes
    /// than it was given — typically a full disk. Previously ignored, which
    /// left a short MP3 that the pipeline then called finished.
    case couldNotWriteOutput(url: URL)
}
