import Foundation

/// Per-user referral code issuance cap — must match drinkmatch-backend's
/// `app_settings.referral_code_cap` (enforced authoritatively server-side
/// in `issue_referral_code()`; this constant only drives when the client
/// proactively disables the "発行" button instead of making a call that's
/// certain to be rejected).
let maxReferralCodesPerUser = 3

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
