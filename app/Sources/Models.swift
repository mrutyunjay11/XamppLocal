import Foundation

struct StackStatus: Codable {
    let projectRoot: String
    let webRoot: String
    let recentWebRoots: [String]?
    let appSupport: String
    let httpPort: Int
    let pmaPort: Int?
    let dbEngine: String
    let dbProfile: String
    let dbPort: Int?
    let phpmyadminAvailable: Bool
    let services: ServicesStatus
    let engines: [EngineInfo]

    enum CodingKeys: String, CodingKey {
        case projectRoot = "project_root"
        case webRoot = "web_root"
        case recentWebRoots = "recent_web_roots"
        case appSupport = "app_support"
        case httpPort = "http_port"
        case pmaPort = "pma_port"
        case dbEngine = "db_engine"
        case dbProfile = "db_profile"
        case dbPort = "db_port"
        case phpmyadminAvailable = "phpmyadmin_available"
        case services, engines
    }
}

struct ServicesStatus: Codable {
    let apache: ServiceState
    let phpFpm: ServiceState
    let db: DBServiceState

    enum CodingKeys: String, CodingKey {
        case apache
        case phpFpm = "php_fpm"
        case db
    }
}

struct ServiceState: Codable {
    let status: String
    let pid: Int32?
    let port: Int?
    let socket: String?
    let footprintMb: Double

    enum CodingKeys: String, CodingKey {
        case status, pid, port, socket
        case footprintMb = "footprint_mb"
    }

    var isRunning: Bool { status == "running" }
}

struct DBServiceState: Codable {
    let status: String
    let engine: String
    let pid: Int32?
    let port: Int?
    let socket: String?
    let footprintMb: Double

    enum CodingKeys: String, CodingKey {
        case status, engine, pid, port, socket
        case footprintMb = "footprint_mb"
    }

    var isRunning: Bool { status == "running" }
}

struct EngineInfo: Codable {
    let id: String
    let name: String
    let source: String
    let installed: Bool
    let active: Bool
    let state: String
    let port: Int?
}

