import Foundation
import Testing
@testable import OCTrainingLog

struct TodayAPIClientTests {
    @Test func sendsBearerTokenAndDecodesPublishedProgramming() async throws {
        let data = Data(Self.publishedJSON.utf8)
        let session = MockHTTPDataLoader(data: data, statusCode: 200)
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )

        let response = try await client.fetchToday(
            track: .generalPopulation,
            accessToken: "member-access-token"
        )

        let request = await session.capturedRequest()
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer member-access-token")
        #expect(request?.url?.absoluteString == "https://api.example.test/api/today?track=GP")

        guard case .published(let published) = response else {
            Issue.record("Expected published programming")
            return
        }
        #expect(published.track.code == .generalPopulation)
        #expect(published.programmingDay.blocks.first?.movements.first?.name == "Back Squat")
    }

    @Test func mapsTrackDenialWithoutReadingPrivateErrorDetails() async throws {
        let session = MockHTTPDataLoader(
            data: Data(#"{"error":"track_access_denied","private":"do-not-read"}"#.utf8),
            statusCode: 403
        )
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )

        await #expect(throws: TodayAPIError.trackAccessDenied) {
            try await client.fetchToday(
                track: .sportsPerformance,
                accessToken: "member-access-token"
            )
        }
    }

    @Test func requestsAnExplicitWorkoutDateForDelayedNotificationNavigation() async throws {
        let session = MockHTTPDataLoader(data: Data(Self.publishedJSON.utf8), statusCode: 200)
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )

        _ = try await client.fetchToday(
            track: .generalPopulation,
            workoutDate: "2026-08-04",
            accessToken: "member-access-token"
        )

        let request = await session.capturedRequest()
        #expect(
            request?.url?.absoluteString
                == "https://api.example.test/api/today?track=GP&date=2026-08-04"
        )
    }

    @Test func postsWeightedCompletionWithBearerToken() async throws {
        let data = Data(Self.completionJSON.utf8)
        let session = MockHTTPDataLoader(data: data, statusCode: 200)
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )

        let response = try await client.completeWorkout(
            WorkoutCompletionRequest(
                clientRequestId: UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
                trackCode: .generalPopulation,
                programmingDayId: UUID(uuidString: "00000000-0000-0000-0000-000000000822")!,
                workoutDate: "2026-09-02",
                notes: nil,
                results: [
                    .weightedFixed(
                        prescribedMovementId: UUID(
                            uuidString: "00000000-0000-0000-0000-000000001312"
                        )!,
                        weightLb: 53.5
                    )
                ]
            ),
            accessToken: "member-access-token"
        )

        let request = await session.capturedRequest()
        #expect(request?.httpMethod == "POST")
        #expect(request?.url?.absoluteString == "https://api.example.test/api/workouts/complete")
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer member-access-token")
        let body = try #require(request?.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let results = try #require(json["results"] as? [[String: Any]])
        #expect(results.first?["resultSchema"] as? String == "weighted_fixed_reps")
        #expect(results.first?["weightLb"] as? Double == 53.5)
        #expect(response.state == "completed")
        #expect(response.results.count == 3)
    }

    @Test func mapsCompletionConflictWithoutReadingResponseDetails() async throws {
        let session = MockHTTPDataLoader(
            data: Data(#"{"error":"completion_conflict","private":"do-not-read"}"#.utf8),
            statusCode: 409
        )
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )

        await #expect(throws: TodayAPIError.completionConflict) {
            try await client.completeWorkout(
                WorkoutCompletionRequest(
                    clientRequestId: UUID(),
                    trackCode: .generalPopulation,
                    programmingDayId: UUID(),
                    workoutDate: "2026-09-02",
                    notes: nil,
                    results: [.weightedFixed(prescribedMovementId: UUID(), weightLb: 10)]
                ),
                accessToken: "member-access-token"
            )
        }
    }

    @Test func postsFreeTextWorkoutWithBearerToken() async throws {
        let session = MockHTTPDataLoader(data: Data(Self.completionJSON.utf8), statusCode: 200)
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )

        _ = try await client.completeFreeTextWorkout(
            FreeTextWorkoutRequest(
                clientRequestId: UUID(
                    uuidString: "10000000-0000-4000-8000-000000000001"
                )!,
                trackCode: .generalPopulation,
                workoutDate: "2026-09-02",
                title: "Trail run",
                notes: "Ran easy for 30 minutes."
            ),
            accessToken: "member-access-token"
        )

        let request = await session.capturedRequest()
        #expect(request?.httpMethod == "POST")
        #expect(request?.url?.absoluteString == "https://api.example.test/api/workouts/free-text")
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer member-access-token")
        let body = try #require(request?.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["trackCode"] as? String == "GP")
        #expect(json["title"] as? String == "Trail run")
        #expect(json["notes"] as? String == "Ran easy for 30 minutes.")
        #expect(json["programmingDayId"] == nil)
    }

    @Test func fetchesTrackHistoryWithBearerToken() async throws {
        let session = MockHTTPDataLoader(
            data: Data(Self.historyJSON.utf8),
            statusCode: 200
        )
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )

        let history = try await client.fetchHistory(
            track: .sportsPerformance,
            accessToken: "member-access-token"
        )

        let request = await session.capturedRequest()
        #expect(request?.url?.absoluteString == "https://api.example.test/api/history?track=SP")
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer member-access-token")
        #expect(history.workouts.first?.movements.first?.isPersonalRecord == true)
        #expect(history.workouts.first?.movements[1].formattedResult == "01:41.5")
        #expect(history.workouts.first?.movements[2].formattedResult == "6.5 ft")
    }

    @Test func sendsHistorySearchDatePRAndCursorParameters() async throws {
        let session = MockHTTPDataLoader(
            data: Data(Self.historyJSON.utf8),
            statusCode: 200
        )
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )

        _ = try await client.fetchHistory(
            track: .generalPopulation,
            query: "deadlift",
            fromDate: "2026-08-01",
            personalRecordsOnly: true,
            cursor: "10000000-0000-4000-8000-000000000001",
            accessToken: "member-access-token"
        )

        let captured = await session.capturedRequest()
        let url = try #require(captured?.url)
        let components = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)
        )
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })
        #expect(values["track"] == "GP")
        #expect(values["query"] == "deadlift")
        #expect(values["from"] == "2026-08-01")
        #expect(values["pr"] == "true")
        #expect(values["cursor"] == "10000000-0000-4000-8000-000000000001")
    }

    @Test func requestsOneSourceWorkoutByIdentifier() async throws {
        let session = MockHTTPDataLoader(
            data: Data(Self.historyJSON.utf8),
            statusCode: 200
        )
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )
        let workoutLogId = UUID(
            uuidString: "10000000-0000-4000-8000-000000000001"
        )!

        _ = try await client.fetchHistory(
            track: .sportsPerformance,
            workoutLogId: workoutLogId,
            accessToken: "member-access-token"
        )

        let captured = await session.capturedRequest()
        let components = try #require(
            captured?.url.flatMap {
                URLComponents(url: $0, resolvingAgainstBaseURL: false)
            }
        )
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })
        #expect(values == [
            "track": "SP",
            "workout": workoutLogId.uuidString.lowercased()
        ])
    }

    @Test func patchesFreeTextWorkoutWithExpectedVersion() async throws {
        let responseJSON = #"""
        {
          "state":"updated",
          "workoutLogId":"20000000-0000-4000-8000-000000000001",
          "updatedAt":"2026-09-02T18:31:00.000Z"
        }
        """#
        let session = MockHTTPDataLoader(data: Data(responseJSON.utf8), statusCode: 200)
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )
        _ = try await client.editFreeTextWorkout(
            FreeTextWorkoutEditRequest(
                workoutLogId: UUID(
                    uuidString: "20000000-0000-4000-8000-000000000001"
                )!,
                expectedUpdatedAt: "2026-09-02T18:30:00.000Z",
                title: "Updated trail run",
                notes: "Exact updated details"
            ),
            accessToken: "member-access-token"
        )

        let request = await session.capturedRequest()
        #expect(request?.httpMethod == "PATCH")
        #expect(
            request?.url?.absoluteString
                == "https://api.example.test/api/workouts/free-text/edit"
        )
        let body = try #require(request?.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["title"] as? String == "Updated trail run")
        #expect(json["expectedUpdatedAt"] as? String == "2026-09-02T18:30:00.000Z")
    }

    @Test func requestsTrackScopedPersonalRecordDetail() async throws {
        let session = MockHTTPDataLoader(data: Data("{}".utf8), statusCode: 200)
        let client = TodayAPIClient(
            configuration: try APIConfiguration(values: [
                "OCAPIBaseURL": "https://api.example.test"
            ]),
            session: session
        )
        let benchmarkId = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
        _ = try await client.fetchPersonalRecords(
            track: .generalPopulation,
            benchmarkId: benchmarkId,
            accessToken: "member-access-token"
        )
        let captured = await session.capturedRequest()
        let url = try #require(captured?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })
        #expect(values["track"] == "GP")
        #expect(values["benchmark"] == benchmarkId.uuidString.lowercased())
    }

    private static let publishedJSON = #"""
        {
          "state": "published",
          "workoutDate": "2026-08-04",
          "timeZone": "America/Los_Angeles",
          "isCompleted": false,
          "track": {
            "id": "00000000-0000-0000-0000-000000000202",
            "code": "GP",
            "name": "General Population"
          },
          "programmingDay": {
            "id": "00000000-0000-0000-0000-000000000801",
            "title": "Tuesday GP",
            "coachNotes": null,
            "blocks": [
              {
                "id": "00000000-0000-0000-0000-000000000901",
                "type": "strength",
                "title": "Strength",
                "instructions": null,
                "displayOrder": 0,
                "movements": [
                  {
                    "id": "00000000-0000-0000-0000-000000001001",
                    "movementId": "00000000-0000-0000-0000-000000000704",
                    "name": "Back Squat",
                    "prescriptionText": "4 x 5 @ 75%",
                    "coachNotes": null,
                    "substitutions": [],
                    "resultSchema": "weighted_fixed_reps",
                    "displayOrder": 0
                  }
                ]
              }
            ]
          }
        }
        """#

    private static let completionJSON = #"""
        {
          "state": "completed",
          "workoutLogId": "20000000-0000-4000-8000-000000000001",
          "completedAt": "2026-09-02T18:30:00.000Z",
          "replayed": false,
          "results": [
            {
              "resultSchema": "weighted_fixed_reps",
              "movementResultId": "30000000-0000-4000-8000-000000000001",
              "prescribedMovementId": "00000000-0000-0000-0000-000000001312",
              "weightLb": 53.5
            },
            {
              "resultSchema": "for_time",
              "movementResultId": "30000000-0000-4000-8000-000000000002",
              "prescribedMovementId": "00000000-0000-0000-0000-000000001313",
              "durationMs": 101500
            },
            {
              "resultSchema": "height_or_distance",
              "movementResultId": "30000000-0000-4000-8000-000000000003",
              "prescribedMovementId": "00000000-0000-0000-0000-000000001314",
              "measurementValue": 24.25,
              "measurementUnit": "in"
            }
          ],
          "personalRecords": []
        }
        """#

    private static let historyJSON = #"""
        {
          "track": {
            "id": "00000000-0000-0000-0000-000000000201",
            "code": "SP",
            "name": "Sports Performance"
          },
          "workouts": [
            {
              "workoutLogId": "10000000-0000-4000-8000-000000000001",
              "programmingDayId": "00000000-0000-0000-0000-000000000813",
              "workoutDate": "2026-07-25",
              "completedAt": "2026-07-25T18:30:00.000Z",
              "updatedAt": "2026-07-25T18:30:00.000Z",
              "title": "SP Front Squat and Lower Body Strength",
              "notes": null,
              "hasPersonalRecord": true,
              "movements": [
                {
                  "movementResultId": "20000000-0000-4000-8000-000000000001",
                  "prescribedMovementId": "00000000-0000-0000-0000-000000001073",
                  "name": "Front Squat",
                  "prescriptionText": "5-rep front squat to 12-inch box plus foam",
                  "blockType": "strength",
                  "resultSchema": "weighted_fixed_reps",
                  "weightLb": 315,
                  "isPersonalRecord": true
                },
                {
                  "movementResultId": "20000000-0000-4000-8000-000000000002",
                  "prescribedMovementId": "00000000-0000-0000-0000-000000001074",
                  "name": "500 m row",
                  "prescriptionText": "For time",
                  "blockType": "wod",
                  "resultSchema": "for_time",
                  "durationMs": 101500,
                  "isPersonalRecord": false
                },
                {
                  "movementResultId": "20000000-0000-4000-8000-000000000003",
                  "prescribedMovementId": "00000000-0000-0000-0000-000000001075",
                  "name": "Standing Broad Jump",
                  "prescriptionText": "Record max distance",
                  "blockType": "jumps",
                  "resultSchema": "height_or_distance",
                  "measurementValue": 6.5,
                  "measurementUnit": "ft",
                  "isPersonalRecord": false
                }
              ]
            }
          ]
        }
        """#
}

private actor MockHTTPDataLoader: HTTPDataLoading {
    private let data: Data
    private let statusCode: Int
    private var request: URLRequest?

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (data, response)
    }

    func capturedRequest() -> URLRequest? {
        request
    }
}
