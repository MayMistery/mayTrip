
import Foundation
import CoreLocation

struct AirportRecord: Identifiable, Hashable, Sendable {
    var id: String { iata }
    var iata: String
    var nameZH: String
    var nameEN: String
    var cityZH: String
    var cityEN: String
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String { "\(nameZH) \(iata)" }

    var bilingualName: String { "\(nameZH) \(nameEN)" }
}

/// A compact, offline IATA list for paste and flight entry. Not a live timetable.
enum AirportCatalog {
    static func airport(iata: String) -> AirportRecord? {
        let key = iata.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return all.first { $0.iata == key }
    }

    static func search(_ query: String) -> [AirportRecord] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        let upper = needle.uppercased()
        return all.filter { airport in
            airport.iata == upper
                || airport.nameZH.contains(needle)
                || airport.nameEN.localizedCaseInsensitiveContains(needle)
                || airport.cityZH.contains(needle)
                || airport.cityEN.localizedCaseInsensitiveContains(needle)
        }
    }

    static let all: [AirportRecord] = [
        .init(iata: "PEK", nameZH: "北京首都国际机场", nameEN: "Beijing Capital", cityZH: "北京", cityEN: "Beijing", latitude: 40.0799, longitude: 116.6031, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "PKX", nameZH: "北京大兴国际机场", nameEN: "Beijing Daxing", cityZH: "北京", cityEN: "Beijing", latitude: 39.5099, longitude: 116.4107, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "PVG", nameZH: "上海浦东国际机场", nameEN: "Shanghai Pudong", cityZH: "上海", cityEN: "Shanghai", latitude: 31.1443, longitude: 121.8083, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "SHA", nameZH: "上海虹桥国际机场", nameEN: "Shanghai Hongqiao", cityZH: "上海", cityEN: "Shanghai", latitude: 31.1979, longitude: 121.3363, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "CAN", nameZH: "广州白云国际机场", nameEN: "Guangzhou Baiyun", cityZH: "广州", cityEN: "Guangzhou", latitude: 23.3924, longitude: 113.2988, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "SZX", nameZH: "深圳宝安国际机场", nameEN: "Shenzhen Bao'an", cityZH: "深圳", cityEN: "Shenzhen", latitude: 22.6393, longitude: 113.8108, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "CTU", nameZH: "成都双流国际机场", nameEN: "Chengdu Shuangliu", cityZH: "成都", cityEN: "Chengdu", latitude: 30.5785, longitude: 103.9470, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "TFU", nameZH: "成都天府国际机场", nameEN: "Chengdu Tianfu", cityZH: "成都", cityEN: "Chengdu", latitude: 30.3190, longitude: 104.4450, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "HGH", nameZH: "杭州萧山国际机场", nameEN: "Hangzhou Xiaoshan", cityZH: "杭州", cityEN: "Hangzhou", latitude: 30.2361, longitude: 120.4340, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "XIY", nameZH: "西安咸阳国际机场", nameEN: "Xi'an Xianyang", cityZH: "西安", cityEN: "Xi'an", latitude: 34.4347, longitude: 108.7516, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "CKG", nameZH: "重庆江北国际机场", nameEN: "Chongqing Jiangbei", cityZH: "重庆", cityEN: "Chongqing", latitude: 29.7192, longitude: 106.6417, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "KMG", nameZH: "昆明长水国际机场", nameEN: "Kunming Changshui", cityZH: "昆明", cityEN: "Kunming", latitude: 25.1019, longitude: 102.9292, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "WUH", nameZH: "武汉天河国际机场", nameEN: "Wuhan Tianhe", cityZH: "武汉", cityEN: "Wuhan", latitude: 30.7838, longitude: 114.2081, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "NKG", nameZH: "南京禄口国际机场", nameEN: "Nanjing Lukou", cityZH: "南京", cityEN: "Nanjing", latitude: 31.7420, longitude: 118.8620, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "XMN", nameZH: "厦门高崎国际机场", nameEN: "Xiamen Gaoqi", cityZH: "厦门", cityEN: "Xiamen", latitude: 24.5440, longitude: 118.1277, timeZoneIdentifier: "Asia/Shanghai"),
        .init(iata: "HKG", nameZH: "香港国际机场", nameEN: "Hong Kong International", cityZH: "香港", cityEN: "Hong Kong", latitude: 22.3080, longitude: 113.9185, timeZoneIdentifier: "Asia/Hong_Kong"),
        .init(iata: "MFM", nameZH: "澳门国际机场", nameEN: "Macau International", cityZH: "澳门", cityEN: "Macau", latitude: 22.1496, longitude: 113.5910, timeZoneIdentifier: "Asia/Macau"),
        .init(iata: "TPE", nameZH: "台湾桃园国际机场", nameEN: "Taiwan Taoyuan", cityZH: "台北", cityEN: "Taipei", latitude: 25.0777, longitude: 121.2328, timeZoneIdentifier: "Asia/Taipei"),
        .init(iata: "NRT", nameZH: "成田国际机场", nameEN: "Narita", cityZH: "东京", cityEN: "Tokyo", latitude: 35.7647, longitude: 140.3864, timeZoneIdentifier: "Asia/Tokyo"),
        .init(iata: "HND", nameZH: "东京国际机场", nameEN: "Haneda", cityZH: "东京", cityEN: "Tokyo", latitude: 35.5494, longitude: 139.7798, timeZoneIdentifier: "Asia/Tokyo"),
        .init(iata: "KIX", nameZH: "关西国际机场", nameEN: "Kansai", cityZH: "大阪", cityEN: "Osaka", latitude: 34.4347, longitude: 135.2440, timeZoneIdentifier: "Asia/Tokyo"),
        .init(iata: "ICN", nameZH: "仁川国际机场", nameEN: "Incheon", cityZH: "首尔", cityEN: "Seoul", latitude: 37.4602, longitude: 126.4407, timeZoneIdentifier: "Asia/Seoul"),
        .init(iata: "SIN", nameZH: "新加坡樟宜机场", nameEN: "Singapore Changi", cityZH: "新加坡", cityEN: "Singapore", latitude: 1.3644, longitude: 103.9915, timeZoneIdentifier: "Asia/Singapore"),
        .init(iata: "BKK", nameZH: "苏瓦纳普国际机场", nameEN: "Suvarnabhumi", cityZH: "曼谷", cityEN: "Bangkok", latitude: 13.6900, longitude: 100.7501, timeZoneIdentifier: "Asia/Bangkok"),
        .init(iata: "MAD", nameZH: "马德里巴拉哈斯机场", nameEN: "Adolfo Suárez Madrid-Barajas", cityZH: "马德里", cityEN: "Madrid", latitude: 40.4983, longitude: -3.5676, timeZoneIdentifier: "Europe/Madrid"),
        .init(iata: "BCN", nameZH: "巴塞罗那埃尔普拉特机场", nameEN: "Barcelona El Prat", cityZH: "巴塞罗那", cityEN: "Barcelona", latitude: 41.2974, longitude: 2.0833, timeZoneIdentifier: "Europe/Madrid"),
        .init(iata: "AGP", nameZH: "马拉加机场", nameEN: "Málaga-Costa del Sol", cityZH: "马拉加", cityEN: "Malaga", latitude: 36.6749, longitude: -4.4991, timeZoneIdentifier: "Europe/Madrid"),
        .init(iata: "SVQ", nameZH: "塞维利亚机场", nameEN: "Seville", cityZH: "塞维利亚", cityEN: "Seville", latitude: 37.4180, longitude: -5.8931, timeZoneIdentifier: "Europe/Madrid"),
        .init(iata: "LIS", nameZH: "里斯本波尔泰拉机场", nameEN: "Lisbon Humberto Delgado", cityZH: "里斯本", cityEN: "Lisbon", latitude: 38.7756, longitude: -9.1354, timeZoneIdentifier: "Europe/Lisbon"),
        .init(iata: "OPO", nameZH: "波尔图机场", nameEN: "Porto Francisco Sá Carneiro", cityZH: "波尔图", cityEN: "Porto", latitude: 41.2421, longitude: -8.6784, timeZoneIdentifier: "Europe/Lisbon"),
        .init(iata: "CDG", nameZH: "巴黎戴高乐机场", nameEN: "Paris Charles de Gaulle", cityZH: "巴黎", cityEN: "Paris", latitude: 49.0097, longitude: 2.5479, timeZoneIdentifier: "Europe/Paris"),
        .init(iata: "ORY", nameZH: "巴黎奥利机场", nameEN: "Paris Orly", cityZH: "巴黎", cityEN: "Paris", latitude: 48.7233, longitude: 2.3794, timeZoneIdentifier: "Europe/Paris"),
        .init(iata: "LHR", nameZH: "伦敦希思罗机场", nameEN: "London Heathrow", cityZH: "伦敦", cityEN: "London", latitude: 51.4700, longitude: -0.4543, timeZoneIdentifier: "Europe/London"),
        .init(iata: "LGW", nameZH: "伦敦盖特威克机场", nameEN: "London Gatwick", cityZH: "伦敦", cityEN: "London", latitude: 51.1537, longitude: -0.1821, timeZoneIdentifier: "Europe/London"),
        .init(iata: "AMS", nameZH: "阿姆斯特丹史基浦机场", nameEN: "Amsterdam Schiphol", cityZH: "阿姆斯特丹", cityEN: "Amsterdam", latitude: 52.3105, longitude: 4.7683, timeZoneIdentifier: "Europe/Amsterdam"),
        .init(iata: "FRA", nameZH: "法兰克福机场", nameEN: "Frankfurt", cityZH: "法兰克福", cityEN: "Frankfurt", latitude: 50.0379, longitude: 8.5622, timeZoneIdentifier: "Europe/Berlin"),
        .init(iata: "MUC", nameZH: "慕尼黑机场", nameEN: "Munich", cityZH: "慕尼黑", cityEN: "Munich", latitude: 48.3537, longitude: 11.7750, timeZoneIdentifier: "Europe/Berlin"),
        .init(iata: "FCO", nameZH: "罗马菲乌米奇诺机场", nameEN: "Rome Fiumicino", cityZH: "罗马", cityEN: "Rome", latitude: 41.8003, longitude: 12.2389, timeZoneIdentifier: "Europe/Rome"),
        .init(iata: "MXP", nameZH: "米兰马尔彭萨机场", nameEN: "Milan Malpensa", cityZH: "米兰", cityEN: "Milan", latitude: 45.6306, longitude: 8.7281, timeZoneIdentifier: "Europe/Rome"),
        .init(iata: "ZRH", nameZH: "苏黎世机场", nameEN: "Zurich", cityZH: "苏黎世", cityEN: "Zurich", latitude: 47.4583, longitude: 8.5555, timeZoneIdentifier: "Europe/Zurich"),
        .init(iata: "VIE", nameZH: "维也纳机场", nameEN: "Vienna", cityZH: "维也纳", cityEN: "Vienna", latitude: 48.1103, longitude: 16.5697, timeZoneIdentifier: "Europe/Vienna"),
        .init(iata: "DUB", nameZH: "都柏林机场", nameEN: "Dublin", cityZH: "都柏林", cityEN: "Dublin", latitude: 53.4264, longitude: -6.2499, timeZoneIdentifier: "Europe/Dublin"),
        .init(iata: "ATH", nameZH: "雅典国际机场", nameEN: "Athens", cityZH: "雅典", cityEN: "Athens", latitude: 37.9364, longitude: 23.9445, timeZoneIdentifier: "Europe/Athens"),
        .init(iata: "IST", nameZH: "伊斯坦布尔机场", nameEN: "Istanbul", cityZH: "伊斯坦布尔", cityEN: "Istanbul", latitude: 41.2753, longitude: 28.7519, timeZoneIdentifier: "Europe/Istanbul"),
        .init(iata: "JFK", nameZH: "纽约肯尼迪国际机场", nameEN: "New York JFK", cityZH: "纽约", cityEN: "New York", latitude: 40.6413, longitude: -73.7781, timeZoneIdentifier: "America/New_York"),
        .init(iata: "EWR", nameZH: "纽瓦克自由国际机场", nameEN: "Newark Liberty", cityZH: "纽约", cityEN: "New York", latitude: 40.6895, longitude: -74.1745, timeZoneIdentifier: "America/New_York"),
        .init(iata: "LAX", nameZH: "洛杉矶国际机场", nameEN: "Los Angeles", cityZH: "洛杉矶", cityEN: "Los Angeles", latitude: 33.9425, longitude: -118.4081, timeZoneIdentifier: "America/Los_Angeles"),
        .init(iata: "SFO", nameZH: "旧金山国际机场", nameEN: "San Francisco", cityZH: "旧金山", cityEN: "San Francisco", latitude: 37.6213, longitude: -122.3790, timeZoneIdentifier: "America/Los_Angeles"),
        .init(iata: "DXB", nameZH: "迪拜国际机场", nameEN: "Dubai International", cityZH: "迪拜", cityEN: "Dubai", latitude: 25.2532, longitude: 55.3657, timeZoneIdentifier: "Asia/Dubai"),
        .init(iata: "DOH", nameZH: "哈马德国际机场", nameEN: "Hamad International", cityZH: "多哈", cityEN: "Doha", latitude: 25.2731, longitude: 51.6080, timeZoneIdentifier: "Asia/Qatar"),
        .init(iata: "SYD", nameZH: "悉尼金斯福德·史密斯机场", nameEN: "Sydney Kingsford Smith", cityZH: "悉尼", cityEN: "Sydney", latitude: -33.9399, longitude: 151.1753, timeZoneIdentifier: "Australia/Sydney"),
        .init(iata: "MEL", nameZH: "墨尔本机场", nameEN: "Melbourne", cityZH: "墨尔本", cityEN: "Melbourne", latitude: -37.6690, longitude: 144.8410, timeZoneIdentifier: "Australia/Melbourne"),
    ]
}
