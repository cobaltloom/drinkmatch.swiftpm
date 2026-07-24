import Foundation

/// Company / group-company email domains accepted for identity verification.
///
/// NOTE: some domains below were confirmed live during prototype research,
/// others were not — see the handoff doc (§2, §9). All entries must be
/// re-verified before this list is used in production.
enum VerifiedDomains {
    static let all: Set<String> = [
        // 大手
        "ana.co.jp", "jal.co.jp",
        // LCC
        "jetstar.com", "flypeach.com", "springjapan.co.jp", "zipair.net",
        // 地域航空会社
        "skymark.co.jp", "airdo.jp", "solaseedair.jp", "starflyer.jp",
        "amx.co.jp", // 天草エアライン
        "jac.co.jp", // 日本エアコミューター
        "rac-okinawa.com", // 琉球エアーコミューター
        "hac-air.co.jp", // 北海道エアシステム
        // 貨物
        "nca.aero", // 日本貨物航空
        // グループ会社(整備・グランドハンドリング等)
        "anawings.co.jp", // ANAウイングス
        "ana-g.com", // ANAグループの空港サービス各社の共通ドメイン
        "jgsgroup.co.jp", // JALグランドサービス
        "jalec.co.jp", // JALエンジニアリング
    ]
}

enum Roles {
    static let all: [Role] = [
        Role(code: "CPT", label: "機長"),
        Role(code: "F/O", label: "副操縦士"),
        Role(code: "CA", label: "客室乗務員"),
        Role(code: "DISP", label: "運航管理者"),
        Role(code: "MX", label: "整備士"),
        Role(code: "GS", label: "グランドスタッフ"),
        Role(code: "INST", label: "訓練教官"),
        Role(code: "CGO", label: "貨物取扱担当"),
    ]

    static func label(for code: String) -> String {
        all.first { $0.code == code }?.label ?? code
    }
}

enum Bases {
    static let all = ["HND", "NRT", "KIX", "ITM", "CTS", "FUK", "OKA", "NGO"]
}

enum StayAirports {
    static let all: [Airport] = [
        // 北海道
        Airport(code: "CTS", name: "新千歳(札幌)"),
        Airport(code: "OKD", name: "丘珠(札幌)"),
        Airport(code: "HKD", name: "函館"),
        Airport(code: "AKJ", name: "旭川"),
        Airport(code: "KUH", name: "釧路"),
        Airport(code: "MMB", name: "女満別"),
        Airport(code: "OBO", name: "帯広"),
        Airport(code: "WKJ", name: "稚内"),
        // 東北
        Airport(code: "AOJ", name: "青森"),
        Airport(code: "AXT", name: "秋田"),
        Airport(code: "SDJ", name: "仙台"),
        Airport(code: "GAJ", name: "山形"),
        Airport(code: "HNA", name: "花巻(岩手)"),
        Airport(code: "FKS", name: "福島"),
        // 関東
        Airport(code: "HND", name: "羽田(東京)"),
        Airport(code: "NRT", name: "成田(東京)"),
        Airport(code: "IBR", name: "茨城"),
        // 中部・北陸
        Airport(code: "NGO", name: "中部(名古屋)"),
        Airport(code: "NKM", name: "小牧(名古屋)"),
        Airport(code: "KMQ", name: "小松(石川)"),
        Airport(code: "NTQ", name: "能登"),
        Airport(code: "TOY", name: "富山"),
        Airport(code: "FSZ", name: "静岡"),
        Airport(code: "MMJ", name: "松本(長野)"),
        Airport(code: "NGT", name: "新潟"),
        // 近畿
        Airport(code: "KIX", name: "関西(大阪)"),
        Airport(code: "ITM", name: "伊丹(大阪)"),
        Airport(code: "UKB", name: "神戸"),
        Airport(code: "TJH", name: "但馬"),
        Airport(code: "SHM", name: "南紀白浜"),
        // 中国
        Airport(code: "OKJ", name: "岡山"),
        Airport(code: "HIJ", name: "広島"),
        Airport(code: "IWK", name: "岩国"),
        Airport(code: "YGJ", name: "米子"),
        Airport(code: "TTJ", name: "石見"),
        Airport(code: "UBJ", name: "山口宇部"),
        // 四国
        Airport(code: "TAK", name: "高松"),
        Airport(code: "MYJ", name: "松山"),
        Airport(code: "KCZ", name: "高知"),
        Airport(code: "TKS", name: "徳島"),
        // 九州
        Airport(code: "FUK", name: "福岡"),
        Airport(code: "KKJ", name: "北九州"),
        Airport(code: "NGS", name: "長崎"),
        Airport(code: "HSG", name: "佐賀"),
        Airport(code: "KMJ", name: "熊本"),
        Airport(code: "OIT", name: "大分"),
        Airport(code: "KMI", name: "宮崎"),
        Airport(code: "KOJ", name: "鹿児島"),
        // 沖縄・離島
        Airport(code: "OKA", name: "那覇"),
        Airport(code: "ISG", name: "石垣"),
        Airport(code: "MMY", name: "宮古"),
        Airport(code: "UEO", name: "久米島"),
        // 東アジア
        Airport(code: "ICN", name: "仁川(ソウル)"),
        Airport(code: "GMP", name: "金浦(ソウル)"),
        Airport(code: "PVG", name: "浦東(上海)"),
        Airport(code: "PEK", name: "北京首都"),
        Airport(code: "HKG", name: "香港"),
        Airport(code: "TPE", name: "桃園(台北)"),
        Airport(code: "TSA", name: "松山(台北)"),
        // 東南アジア
        Airport(code: "BKK", name: "スワンナプーム(バンコク)"),
        Airport(code: "SIN", name: "シンガポール・チャンギ"),
        Airport(code: "KUL", name: "クアラルンプール"),
        Airport(code: "MNL", name: "マニラ"),
        Airport(code: "CGK", name: "ジャカルタ"),
        Airport(code: "SGN", name: "ホーチミン"),
        Airport(code: "HAN", name: "ハノイ"),
        // 南アジア・中東
        Airport(code: "DEL", name: "デリー"),
        Airport(code: "BOM", name: "ムンバイ"),
        Airport(code: "DXB", name: "ドバイ"),
        Airport(code: "DOH", name: "ドーハ"),
        // オセアニア
        Airport(code: "SYD", name: "シドニー"),
        Airport(code: "MEL", name: "メルボルン"),
        Airport(code: "GUM", name: "グアム"),
        Airport(code: "HNL", name: "ホノルル"),
        // 北米
        Airport(code: "LAX", name: "ロサンゼルス"),
        Airport(code: "SFO", name: "サンフランシスコ"),
        Airport(code: "SEA", name: "シアトル"),
        Airport(code: "JFK", name: "ニューヨーク・JFK"),
        Airport(code: "ORD", name: "シカゴ・オヘア"),
        Airport(code: "YVR", name: "バンクーバー"),
        // ヨーロッパ
        Airport(code: "LHR", name: "ロンドン・ヒースロー"),
        Airport(code: "CDG", name: "パリ・シャルルドゴール"),
        Airport(code: "FRA", name: "フランクフルト"),
        Airport(code: "AMS", name: "アムステルダム"),
        Airport(code: "FCO", name: "ローマ・フィウミチーノ"),
        Airport(code: "MUC", name: "ミュンヘン"),
    ]
}

/// Demo pool of unknown-to-you crew members shown in the "new match" flow.
enum SampleStrangers {
    static let all: [Person] = [
        Person(id: 101, name: "T.S.", fullName: nil, role: "CA", airline: "ANA", base: "HND", years: 4,
               note: "同期と2人で参加予定",
               stays: [
                StayEntry(day: 6, location: "OKA", from: "19:00"),
                StayEntry(day: 7, location: "OKA", from: "18:00"),
                StayEntry(day: 18, location: "CTS", from: "20:00"),
                StayEntry(day: 25, location: "FUK", from: "19:30"),
               ]),
        Person(id: 102, name: "K.M.", fullName: nil, role: "F/O", airline: "JAL", base: "HND", years: 7,
               note: "ゆっくり飲める方希望",
               stays: [
                StayEntry(day: 6, location: "OKA", from: "20:30"),
                StayEntry(day: 13, location: "KIX", from: "19:00"),
                StayEntry(day: 20, location: "FUK", from: "18:30"),
               ]),
        Person(id: 103, name: "R.O.", fullName: nil, role: "CA", airline: "Jetstar", base: "NRT", years: 2,
               note: "3人グループで参加",
               stays: [
                StayEntry(day: 8, location: "CTS", from: "18:00"),
                StayEntry(day: 15, location: "OKA", from: "19:00"),
                StayEntry(day: 22, location: "FUK", from: "20:00"),
               ]),
        Person(id: 104, name: "Y.H.", fullName: nil, role: "CPT", airline: "ANA", base: "HND", years: 15,
               note: "業界話できる方歓迎",
               stays: [
                StayEntry(day: 7, location: "OKA", from: "21:00"),
                StayEntry(day: 17, location: "KIX", from: "19:30"),
                StayEntry(day: 30, location: "FUK", from: "18:00"),
               ]),
        Person(id: 105, name: "N.I.", fullName: nil, role: "CA", airline: "SKY", base: "KIX", years: 3,
               note: "大阪ベースの方と繋がりたい",
               stays: [
                StayEntry(day: 13, location: "KIX", from: "19:00"),
                StayEntry(day: 19, location: "FUK", from: "18:30"),
                StayEntry(day: 28, location: "OKA", from: "20:00"),
               ]),
    ]
}

/// Invite codes used to add someone as a known acquaintance ("friend").
enum InviteCodes {
    static let all: [String: Person] = [
        "PILOT2024": Person(id: 201, name: "M.F.", fullName: "藤田 誠", role: "F/O", airline: "ANA", base: "HND", years: 5,
                             note: "元同期です、久々に集合しましょう",
                             stays: [
                                StayEntry(day: 6, location: "OKA", from: "19:30"),
                                StayEntry(day: 19, location: "FUK", from: "18:00"),
                                StayEntry(day: 26, location: "KIX", from: "20:00"),
                             ]),
        "CREW-AYA": Person(id: 202, name: "A.Y.", fullName: "吉田 彩", role: "CA", airline: "JAL", base: "NRT", years: 6,
                            note: "研修同期です",
                            stays: [
                                StayEntry(day: 7, location: "OKA", from: "18:30"),
                                StayEntry(day: 14, location: "CTS", from: "19:00"),
                                StayEntry(day: 28, location: "OKA", from: "20:30"),
                            ]),
    ]
}

enum SampleFriends {
    static let initial: [Person] = [
        Person(id: 301, name: "S.K.", fullName: "小林 沙耶", role: "CA", airline: "ANA", base: "HND", years: 5,
               note: "大学の後輩です",
               stays: [
                StayEntry(day: 6, location: "OKA", from: "19:00"),
                StayEntry(day: 13, location: "KIX", from: "18:30"),
                StayEntry(day: 20, location: "FUK", from: "19:00"),
               ]),
        Person(id: 302, name: "H.T.", fullName: "田中 陽介", role: "CPT", airline: "JAL", base: "HND", years: 12,
               note: "訓練同期です",
               stays: [
                StayEntry(day: 6, location: "OKA", from: "20:00"),
                StayEntry(day: 18, location: "CTS", from: "19:00"),
                StayEntry(day: 25, location: "FUK", from: "18:00"),
               ]),
    ]
}

let maxReferralCodesPerUser = 3

/// Demo referral codes issued by other already-verified users.
enum SampleReferralCodes {
    static let initial: [String: ReferralCodeEntry] = [
        "SENPAI-T7K2": ReferralCodeEntry(referrerName: "田中 陽介", used: false),
        "SENPAI-M9Q4": ReferralCodeEntry(referrerName: "小林 沙耶", used: false),
    ]
}
