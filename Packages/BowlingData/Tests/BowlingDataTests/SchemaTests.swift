import Foundation
import SwiftData
import Testing
@testable import BowlingData

@Suite struct SchemaTests {
    @Test func inMemoryContainerLoadsEveryEntity() throws {
        let container = try BowlingStore.makeContainer(inMemory: true)
        let names = Set(container.schema.entities.map(\.name))
        #expect(names == [
            "Bowler", "Session", "Game", "Frame", "Roll", "Ball", "GamePhoto", "BallPhoto",
            "MaintenanceEvent", "BowlingCenter", "League", "OilPattern",
        ])
    }

    @Test func everyRelationshipIsOptionalWithAnInverse() throws {
        for entity in BowlingStore.schema.entities {
            for relationship in entity.relationships {
                #expect(relationship.isOptional, "\(entity.name).\(relationship.name)")
                #expect(relationship.inverseName != nil, "\(entity.name).\(relationship.name)")
            }
        }
    }

    @Test func noAttributeIsUnique() {
        for entity in BowlingStore.schema.entities {
            for attribute in entity.attributes {
                #expect(!attribute.isUnique, "\(entity.name).\(attribute.name)")
            }
        }
    }

    @Test(arguments: ["GamePhoto", "BallPhoto"])
    func photoDataUsesExternalStorage(entityName: String) throws {
        let entity = try #require(BowlingStore.schema.entitiesByName[entityName])
        let imageData = try #require(entity.attributesByName["imageData"])
        #expect(imageData.options.contains(.externalStorage))
    }

    @Test func savedModelsGetDistinctIDsAndTimestamps() throws {
        let container = try BowlingStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let first = Bowler(name: "A", isOwner: true)
        let second = Bowler(name: "B")
        context.insert(first)
        context.insert(second)
        try context.save()

        #expect(first.id != second.id)
        #expect(first.createdAt <= first.updatedAt)
        #expect(first.remoteID == nil)
    }
}
