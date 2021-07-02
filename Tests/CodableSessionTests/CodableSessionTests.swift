// MIT License
// Copyright (c) 2021 Ben Waidhofer

import Foundation
import XCTest
@testable import CodableSession

@available(macOS 12.0, *)
@available(iOS 15.0, *)
final class CodableSessionTests: XCTestCase {
    func testVersion() throws {
        XCTAssertEqual(CodableSessionLibrary().version, "0.0.1")
    }
    
    func testGet() throws {
        let getExpectation = expectation(description: "get an item and then an array of items")

        Task {
            let decoded : TestModel = try await CodableRequest().get("https://jsonplaceholder.typicode.com/posts/1")
            XCTAssert(decoded.userId == 1)
            XCTAssert(decoded.id == 1)
            XCTAssert(!decoded.title.isEmpty)
            XCTAssert(!decoded.body.isEmpty)
            
            let decodedArray : [TestModel] = try await CodableRequest().get("https://jsonplaceholder.typicode.com/posts")
            XCTAssert(decodedArray.count > 0)
            getExpectation.fulfill()
        }

        let _ = XCTWaiter.wait(for: [getExpectation], timeout: 10)
    }

    func testDelete() throws {
        let getExpectation = expectation(description: "delete an item")

        Task {
            try await CodableRequest().delete("https://jsonplaceholder.typicode.com/posts/1")
            getExpectation.fulfill()
        }

        let _ = XCTWaiter.wait(for: [getExpectation], timeout: 10)
    }

    func testPost() throws {
        let postExpectation = expectation(description: "Post an item with one model and get back a different model")

        Task {
            let payload = CreateTestModel(1, "foo", "bar")
            do {
                let decoded : CreateedTestModel = try await CodableRequest().post("https://jsonplaceholder.typicode.com/posts", payload)
                XCTAssert(decoded.id == 101)
                postExpectation.fulfill()
            } catch CodableRequestError.unhealthyMessage(let code, let message) {
                XCTFail("\(code): \(message)")
            } catch CodableRequestError.jsonKeyNotFound(let key, let context, let json) {
                XCTFail("\(key): \(context) \(json)")
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        let _ = XCTWaiter.wait(for: [postExpectation], timeout: 15)
    }
    
    struct TestModel : Codable {
        let userId : Int
        let id : Int
        let title : String
        let body : String
    }
    
    struct CreateTestModel : Codable {
        let userId : Int
        let title : String
        let body : String
        
        init(_ userId: Int, _ title: String, _ body: String) {
            self.userId = userId
            self.title = title
            self.body = body
        }
    }
    
    struct CreateedTestModel : Codable {
        let id : Int
    }
}
