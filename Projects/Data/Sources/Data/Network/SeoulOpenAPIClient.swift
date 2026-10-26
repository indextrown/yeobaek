import Foundation

public enum SeoulOpenAPIError: Error, Equatable, Sendable {
    case missingAPIKey
    case invalidRequest
    case httpStatus(Int)
}

/// 서울 열린데이터광장 Open API를 호출합니다. 응답 해석은 각 저장소가 맡습니다.
public struct SeoulOpenAPIClient: Sendable {
    /// 요청을 보내고 응답 본문과 HTTP 응답을 반환합니다. 테스트에서 교체합니다.
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let apiKey: String
    private let transport: Transport

    /// 인증키와 전송 방식을 지정해 클라이언트를 만듭니다.
    ///
    /// - Parameters:
    ///   - apiKey: 서울 열린데이터광장 일반 인증키입니다.
    ///   - transport: 요청 전송 방식입니다. 기본값은 `URLSession.shared`입니다.
    public init(
        apiKey: String,
        transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }
    ) {
        self.apiKey = apiKey
        self.transport = transport
    }

    /// 장소 하나의 서비스 응답을 받아옵니다.
    ///
    /// - Parameters:
    ///   - service: `citydata_ppltn`, `citydata` 같은 서비스 이름입니다.
    ///   - placeID: 장소 코드입니다. 예: POI009
    /// - Returns: JSON 응답 본문입니다.
    /// - Throws: 인증키가 없거나, 주소를 만들 수 없거나, HTTP 상태가 실패이면 `SeoulOpenAPIError`가 발생합니다.
    public func fetch(
        service: String,
        placeID: String
    ) async throws -> Data {
        guard !apiKey.isEmpty else { throw SeoulOpenAPIError.missingAPIKey }
        guard let request = Self.request(apiKey: apiKey, service: service, placeID: placeID) else {
            throw SeoulOpenAPIError.invalidRequest
        }
        let (data, response) = try await transport(request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SeoulOpenAPIError.httpStatus(http.statusCode)
        }
        return data
    }

    /// 경로 구성 요소를 인코딩해 요청을 만듭니다.
    ///
    /// - Parameters:
    ///   - apiKey: 경로에 넣을 인증키입니다.
    ///   - service: 서비스 이름입니다.
    ///   - placeID: 장소 코드 또는 장소 이름입니다.
    /// - Returns: 15초 제한 시간을 가진 GET 요청이며, 주소를 만들 수 없으면 `nil`입니다.
    static func request(
        apiKey: String,
        service: String,
        placeID: String
    ) -> URLRequest? {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        guard let key = apiKey.addingPercentEncoding(withAllowedCharacters: allowed),
              let place = placeID.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "http://openapi.seoul.go.kr:8088/\(key)/json/\(service)/1/5/\(place)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        return request
    }
}
