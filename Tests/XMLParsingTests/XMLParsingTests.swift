import XCTest
@testable import XMLParsing

let example = """
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship
        Id="rId1"
        Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
        Target="xl/workbook.xml"/>
    <Relationship
        Id="rId2"
        Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties"
        Target="docProps/app.xml"/>
    <Relationship
        Id="rId3"
        Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
        Target="docProps/core.xml"/>
</Relationships>
"""

struct Relationships: Codable {
    let items: [Relationship]

    enum CodingKeys: String, CodingKey {
        case items = "relationship"
    }
}

struct Relationship: Codable {
    enum SchemaType: String, Codable {
        case officeDocument = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
        case extendedProperties = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties"
        case coreProperties = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
    }

    let id: String
    let type: SchemaType
    let target: String

    enum CodingKeys: CodingKey {
        case type
        case id
        case target
    }
}


struct Book: Codable {
    var id: String
    var author: String
    var title: String
    var genre: Genre
    var price: Double
    var publishDate: Date
    var description: String

    enum CodingKeys: String, CodingKey {
        case id, author, title, genre, price, description

        case publishDate = "publish_date"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(id, forKey: .id)
        try c.encode(author, forKey: .author)
        try c.encode(publishDate, forKey: .publishDate)
        try c.encode(genre, forKey: .genre)
        try c.encode(description, forKey: .description)
        try c.encode(title, forKey: .title)
        try c.encode(price, forKey: .price)
    }
}

enum Genre: String, Codable {
    case computer = "Computer"
    case fantasy = "Fantasy"
    case romance = "Romance"
    case horror = "Horror"
    case sciFi = "Science Fiction"
}

let bookXML = """
<?xml version="1.0"?>
<book id="bk101">
<author>Gambardella, Matthew</author>
<title>XML Developer's Guide</title>
<genre>Computer</genre>
<price>44.95</price>
<publish_date>2000-10-01</publish_date>
<description>An in-depth look at creating applications
with XML.</description>
</book>
"""

// TEST FUNCTIONS
extension Book {
    static func retrieveBook() -> Book? {
        guard let data = bookXML.data(using: .utf8) else {
            return nil
        }

        let decoder = XMLDecoder()

        let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()

        decoder.dateDecodingStrategy = .formatted(formatter)

        let book: Book?

        do {
            book = try decoder.decode(Book.self, from: data)
        } catch {
            print(error)

            book = nil
        }

        return book
    }

    func toXML() -> String? {
        let encoder = XMLEncoder()

        let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()

        encoder.dateEncodingStrategy = .formatted(formatter)

        do {
            let data = try encoder.encode(self, withRootKey: "book", header: XMLHeader(version: 1.0))

            return String(data: data, encoding: .utf8)
        } catch {
            print(error)

            return nil
        }
    }
}


let nilXml = """
<root xmlns:xswhatever="http://www.w3.org/2001/XMLSchema-instance">
<empty></empty>
<null xswhatever:nil="true"></null>
</root>
"""

struct NullTest: Decodable {
    let empty: String
    let null: String?
}


let uppercasedXml = """
<ROOT xmlns:xswhatever="http://www.w3.org/2001/XMLSchema-instance">
<NON_EMPTY_VALUE>value</NON_EMPTY_VALUE>
<WHATS_UP_YO xswhatever:nil="true"></WHATS_UP_YO>
</ROOT>
"""

struct UpperTest: Codable {
    let nonEmptyValue: String
    let whatsUpYo: String?
}



class XMLParsingTests: XCTestCase {
    func testExample() {
        do {
            guard let data = example.data(using: .utf8) else { return }

            let decoder = XMLDecoder()
            decoder.keyDecodingStrategy = .convertFromCapitalized

            let rels = try decoder.decode(Relationships.self, from: data)

            XCTAssertEqual(rels.items[0].id, "rId1")
        } catch {
            XCTAssert(false, "failed to decode the example: \(error)")
        }
    }
    
    func testNull() {
        do {
            guard let data = nilXml.data(using: .utf8) else { return }
            
            let decoder = XMLDecoder()
            
            let null = try decoder.decode(NullTest.self, from: data)
            
            XCTAssertEqual(null.empty, "")
            XCTAssertNil(null.null)
        } catch {
            XCTAssert(false, "failed to decode the example: \(error)")
        }
    }
    
    func testUppercase() {
        do {
            guard let data = uppercasedXml.data(using: .utf8) else { return }
            
            let decoder = XMLDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeUpperCase
            
            let test = try decoder.decode(UpperTest.self, from: data)
            
            XCTAssertEqual(test.nonEmptyValue, "value")
            XCTAssertNil(test.whatsUpYo)
            
            let encoder = XMLEncoder()
            
            encoder.keyEncodingStrategy = .convertToSnakeUpperCase
            
            let newData = try encoder.encode(test, withRootKey: "ROOT")
            
            let xmlText = String(data: newData, encoding: .utf8)!
            
            print(xmlText)
            
        } catch {
            XCTAssert(false, "failed to decode / encode the example: \(error)")
        }
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
