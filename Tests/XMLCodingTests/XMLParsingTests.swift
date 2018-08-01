import XCTest
@testable import XMLCoding


class XMLParsingTests: XCTestCase {
    struct Result: Codable {
        let message: String?
        
        enum CodingKeys: String, CodingKey {
            case message = "Message"
        }
    }
    
    struct Metadata: Codable {
        let id: String
        
        enum CodingKeys: String, CodingKey {
            case id = "Id"
        }
    }
    
    struct Response: Codable {
        let result: Result
        let metadata: Metadata
        
        enum CodingKeys: String, CodingKey {
            case result = "Result"
            case metadata = "Metadata"
        }
    }
    
    func testEmptyElement() throws {
        let inputString = """
            <Response>
                <Result/>
                <Metadata>
                    <Id>id</Id>
                </Metadata>
            </Response>
            """
        
        guard let inputData = inputString.data(using: .utf8) else {
            return XCTFail()
        }
        
        let response = try XMLDecoder().decode(Response.self, from: inputData)
        
        XCTAssertNil(response.result.message)
    }

    func testEmptyElementNotEffectingPreviousElement() throws {
        let inputString = """
            <Response>
                <Result>
                    <Message>message</Message>
                </Result>
                <Result/>
                <Metadata>
                    <Id>id</Id>
                </Metadata>
            </Response>
            """
        
        guard let inputData = inputString.data(using: .utf8) else {
            return XCTFail()
        }
        
        let response = try XMLDecoder().decode(Response.self, from: inputData)
        
        XCTAssertEqual("message", response.result.message)
    }

    static var allTests = [
        ("testEmptyElement", testEmptyElement),
    ]
}
