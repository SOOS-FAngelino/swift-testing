//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation) && !SWT_NO_DYNAMIC_LINKING && !SWT_NO_ABI_ENTRY_POINT
@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
private import TestingInternals

@Suite("ABI entry point tests")
struct ABIEntryPointTests {
  @Test func v0() async throws {
    // Get the ABI entry point.
#if os(Linux)
    // The standard Linux linker does not allow exporting symbols from
    // executables, so dlsym() does not let us find this function on that
    // platform when built as an executable rather than a dynamic library.
    let copyABIEntryPoint = abiEntryPoint_v0
#else
    let copyABIEntryPoint = try #require(
      swt_getFunctionWithName(nil, "swt_copyABIEntryPoint_v0").map {
        unsafeBitCast($0, to: (@convention(c) (UnsafeMutableRawPointer) -> Void).self)
      }
    )
#endif
    let abiEntryPoint = UnsafeMutablePointer<ABIEntryPoint_v0>.allocate(capacity: 1)
    copyABIEntryPoint(abiEntryPoint)
    defer {
      abiEntryPoint.deinitialize(count: 1)
      abiEntryPoint.deallocate()
    }

    // Construct arguments and convert them to JSON.
    var arguments = __CommandLineArguments_v0()
    arguments.filter = ["NonExistentTestThatMatchesNothingHopefully"]
    let argumentsJSON = try JSON.withEncoding(of: arguments) { argumentsJSON in
      let result = UnsafeMutableRawBufferPointer.allocate(byteCount: argumentsJSON.count, alignment: 1)
      argumentsJSON.copyBytes(to: result)
      return result
    }
    defer {
      argumentsJSON.deallocate()
    }

    // Call the entry point function.
    let result = await abiEntryPoint.pointee(.init(argumentsJSON)) { eventAndContextJSON in
      let eventAndContext = try! JSON.decode(EventAndContextSnapshot.self, from: eventAndContextJSON)
      _ = (eventAndContext.event, eventAndContext.eventContext)
    }

    // Validate expectations.
    #expect(result == EXIT_SUCCESS)
  }
}
#endif
