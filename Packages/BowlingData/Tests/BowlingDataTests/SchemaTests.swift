import Foundation
import SwiftData
import Testing
@testable import BowlingData

@MainActor @Suite struct SchemaTests {
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

    /// The cascade rows of spec section 3.3. Every other relationship, on both sides, nullifies.
    private static let cascades: Set<String> = [
        "Session.games", "Game.frames", "Frame.rolls", "Game.photo", "Ball.photo", "Ball.maintenance",
    ]

    @Test func deleteRulesMatchTheSpecTable() {
        for entity in BowlingStore.schema.entities {
            for relationship in entity.relationships {
                let name = "\(entity.name).\(relationship.name)"
                #expect(relationship.deleteRule == (Self.cascades.contains(name) ? .cascade : .nullify), "\(name)")
            }
        }
    }

    @Test func relationshipsHaveNoCountLimits() {
        for entity in BowlingStore.schema.entities {
            for relationship in entity.relationships {
                #expect((relationship.minimumModelCount ?? 0) == 0, "\(entity.name).\(relationship.name)")
                let maximum = relationship.maximumModelCount ?? 0
                #expect(maximum == 0 || (relationship.isToOneRelationship && maximum == 1),
                        "\(entity.name).\(relationship.name)")
            }
        }
    }

    @Test func everyAttributeHasADefaultOrIsOptional() {
        for entity in BowlingStore.schema.entities {
            for attribute in entity.attributes {
                #expect(attribute.isOptional || attribute.defaultValue != nil, "\(entity.name).\(attribute.name)")
            }
        }
    }

    @Test func everyEntityHasTheCommonFields() throws {
        for entity in BowlingStore.schema.entities {
            let id = try #require(entity.attributesByName["id"], "\(entity.name)")
            #expect(id.valueType == UUID.self && !id.isOptional, "\(entity.name).id")
            for name in ["createdAt", "updatedAt"] {
                let date = try #require(entity.attributesByName[name], "\(entity.name).\(name)")
                #expect(date.valueType == Date.self && !date.isOptional, "\(entity.name).\(name)")
            }
            let remoteID = try #require(entity.attributesByName["remoteID"], "\(entity.name)")
            #expect(remoteID.valueType == String?.self && remoteID.isOptional, "\(entity.name).remoteID")
        }
    }

    /// The scalar types this schema uses, all mapped to CloudKit fields by
    /// NSPersistentCloudKitContainer. Codable structs and arrays are stored as opaque blobs
    /// that sync cannot merge, so check a new type against CloudKit before listing it here.
    private static let cloudKitTypes: [Any.Type] = [
        String.self, Int.self, Double.self, Bool.self, Date.self, UUID.self, Data.self,
        String?.self, Int?.self, Double?.self, Bool?.self, Date?.self, UUID?.self, Data?.self,
    ]

    @Test func attributeTypesAreCloudKitScalars() {
        for entity in BowlingStore.schema.entities {
            for attribute in entity.attributes {
                #expect(Self.cloudKitTypes.contains { $0 == attribute.valueType },
                        "\(entity.name).\(attribute.name): \(attribute.valueType)")
            }
        }
    }

    @Test func binaryDataLivesOnlyOnPhotoEntities() {
        for entity in BowlingStore.schema.entities where !["GamePhoto", "BallPhoto"].contains(entity.name) {
            for attribute in entity.attributes {
                #expect(attribute.valueType != Data.self && attribute.valueType != Data?.self,
                        "\(entity.name).\(attribute.name)")
            }
        }
    }

    /// Every attribute and relationship name as of the schema review in issue #48. Once phase 2
    /// promotes the CloudKit schema, names may be added but never renamed or removed, so this
    /// list only grows.
    private static let promotedNames: [String: Set<String>] = {
        let common: Set<String> = ["id", "createdAt", "updatedAt", "remoteID"]
        return [
            "Bowler": common.union([
                "name", "isOwner", "handedness", "email", "statsProfile", "statsLayout", "homeLayout",
                "statsScope", "mergedOwnerIDs", "isArchived", "games",
            ]),
            "Session": common.union([
                "date", "eventType", "center", "league", "oilPattern", "lanes", "notes", "games",
            ]),
            "Game": common.union([
                "session", "bowler", "bowlerID", "gameIndex", "lineupIndex", "entryMode", "defaultBall", "finalScore",
                "isComplete", "recordedRollCount", "frames", "photo", "scanConfidence", "invitationStatus", "scoredByName",
            ]),
            "Frame": common.union(["game", "frameIndex", "rolls", "rotationSlot"]),
            "Roll": common.union(["frame", "rollIndex", "pinsDownMask", "pinCount", "pinsKnown", "isFoul", "ball"]),
            "Ball": common.union([
                "name", "brand", "weightPounds", "coverstock", "coverstockName", "coreType", "coreName", "rg",
                "differential", "intermediateDifferential", "intendedRole", "serialNumber", "colorDescription",
                "releaseDate", "purchaseDate", "factoryFinish", "surfaceGrit", "resurfaceIntervalGames",
                "isRetired", "notes", "photo", "maintenance", "gamesAsDefault", "rollsAsOverride",
            ]),
            "GamePhoto": common.union(["imageData", "game"]),
            "BallPhoto": common.union(["imageData", "ball"]),
            "MaintenanceEvent": common.union([
                "ball", "date", "kind", "surfaceGritAfter", "gamesOnBallAtTime", "notes",
            ]),
            "BowlingCenter": common.union(["name", "notes", "city", "latitude", "longitude", "sessions", "leagues"]),
            "League": common.union([
                "name", "notes", "center", "seasonLabel", "seasonStart", "seasonEnd", "gamesPerSession", "sessions",
            ]),
            "OilPattern": common.union([
                "name", "notes", "lengthFeet", "volumeMilliliters", "patternKey", "sessions",
            ]),
        ]
    }()

    @Test func schemaIsAdditiveOnly() throws {
        let entities = BowlingStore.schema.entitiesByName
        for (entityName, names) in Self.promotedNames {
            let entity = try #require(entities[entityName], "\(entityName) was removed or renamed")
            let current = Set(entity.attributes.map(\.name)).union(entity.relationships.map(\.name))
            #expect(names.subtracting(current).isEmpty, "\(entityName) lost \(names.subtracting(current).sorted())")
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

    /// Personal fields encrypted in CloudKit. Encryption cannot be added to a field after the
    /// schema is promoted, so encrypting another field must be a deliberate change here.
    private static let encrypted: Set<String> = ["Bowler.email", "BowlingCenter.latitude", "BowlingCenter.longitude"]

    @Test func onlyPersonalFieldsAreEncrypted() {
        for entity in BowlingStore.schema.entities {
            for attribute in entity.attributes {
                let name = "\(entity.name).\(attribute.name)"
                #expect(attribute.options.contains(.allowsCloudEncryption) == Self.encrypted.contains(name), "\(name)")
            }
        }
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
