//
//  ContentView.swift
//  NoticeTimer
//
//  Created by 古川貴史 on 2024/10/13.
//

import SwiftUI
import AVFoundation
import AudioToolbox
import UIKit
import UserNotifications
import Combine
import GoogleMobileAds
import StoreKit

// アプリがフォアグラウンドの時は、アプリ内蔵のアラーム（音・振動・光）が
// 対応するため、システム通知のバナー/音は重複して出さないようにする
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }
}

// MARK: - アプリ評価（レビュー）依頼の管理
// 次の条件をすべて満たしたユーザーにだけ、タイマー完了後に評価ポップアップを表示する。
//  ・アプリの起動回数が5回以上
//  ・初回起動から3日以上経過
//  ・タイマーを最後まで完了した回数が2回以上
//  ・現在のバージョンでまだ評価依頼を出していない
// ポップアップ自体はApple標準のもの（StoreKit）を使うため、文言は端末の言語設定に
// 合わせてiOSが自動で日本語／英語に切り替える。
// （App Store審査ガイドライン上、独自の評価ダイアログは使用できない）
// なお、iOS側の制限により表示は1ユーザーにつき365日で最大3回まで。
// 条件を満たしてもiOSの判断で表示されないことがある。
enum ReviewManager {
    static let requiredLaunchCount = 5
    static let requiredDaysSinceFirstLaunch = 3
    static let requiredTimerCompletionCount = 2

    private static let launchCountKey = "Review_LaunchCount"
    private static let firstLaunchDateKey = "Review_FirstLaunchDate"
    private static let timerCompletionCountKey = "Review_TimerCompletionCount"
    private static let lastRequestedVersionKey = "Review_LastRequestedVersion"

    private static var defaults: UserDefaults { UserDefaults.standard }

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    // アプリ起動時に1回呼ぶ（起動回数のカウントと初回起動日の記録）
    static func recordAppLaunch() {
        if defaults.object(forKey: firstLaunchDateKey) == nil {
            defaults.set(Date(), forKey: firstLaunchDateKey)
        }
        defaults.set(defaults.integer(forKey: launchCountKey) + 1, forKey: launchCountKey)
    }

    // タイマーが最後まで完了した時に呼ぶ
    static func recordTimerCompletion() {
        defaults.set(defaults.integer(forKey: timerCompletionCountKey) + 1, forKey: timerCompletionCountKey)
    }

    // 評価依頼を出してよい条件を満たしているか
    static func shouldRequestReview() -> Bool {
        guard defaults.integer(forKey: launchCountKey) >= requiredLaunchCount else { return false }
        guard defaults.integer(forKey: timerCompletionCountKey) >= requiredTimerCompletionCount else { return false }
        guard let firstLaunch = defaults.object(forKey: firstLaunchDateKey) as? Date else { return false }
        let days = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
        guard days >= requiredDaysSinceFirstLaunch else { return false }
        // 同じバージョンでは1回だけ
        guard defaults.string(forKey: lastRequestedVersionKey) != currentVersion else { return false }
        return true
    }

    // 評価依頼を出したことを記録する
    static func markRequested() {
        defaults.set(currentVersion, forKey: lastRequestedVersionKey)
    }
}

class AlarmPlayer {
    static let shared = AlarmPlayer()
    var player: AVAudioPlayer?
    var volume: Float = 7.0 / 15.0 // スライダーの初期値(7)に合わせた音量
    
    // 音量を設定するメソッド
    func setVolume(_ vol: Float) {
        self.volume = vol
        player?.volume = vol
    }
    
    func play() {
        // Assets.xcassets に追加された "alarm" 音源データを取得
        guard let asset = NSDataAsset(name: "alarm") else {
            print("エラー: 'alarm' 音源が見つかりません。Assets.xcassetsのファイル名を確認してください。")
            return
        }
        
        do {
            // マナーモード（消音モード）でも音を鳴らすための設定
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(data: asset.data)
            player?.volume = self.volume // 設定された音量を適用
            player?.numberOfLoops = -1 // 無限ループ
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("アラームの再生に失敗しました: \(error)")
        }
    }
    
    func stop() {
        player?.stop()
        player = nil // リセット
    }
}

struct TimerHistory: Identifiable, Codable, Equatable {
    var id = UUID()
    var totalSeconds: Int
    var isAlarmActive: Bool
    var isLightActive: Bool
    var isVaibrationActive: Bool
    var isPushNotificationActive: Bool = false // 既存の保存データ（この項目が無いもの）も読み込めるようデフォルト値を用意

    var displayText: String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        let alarmStr = isAlarmActive ? "◼︎" : "◻︎"
        let lightStr = isLightActive ? "◼︎" : "◻︎"
        let vibStr = isVaibrationActive ? "◼︎" : "◻︎"
        let pushStr = isPushNotificationActive ? "◼︎" : "◻︎"
        return String(format: "%02d:%02d.00  %@_%@_%@_%@", m, s, alarmStr, lightStr, vibStr, pushStr)
    }

    // 旧バージョンで保存された履歴データ（isPushNotificationActiveを含まない）も
    // デコードエラーにならず読み込めるように、decodeIfPresentでフォールバックする
    enum CodingKeys: String, CodingKey {
        case id, totalSeconds, isAlarmActive, isLightActive, isVaibrationActive, isPushNotificationActive
    }

    init(id: UUID = UUID(), totalSeconds: Int, isAlarmActive: Bool, isLightActive: Bool, isVaibrationActive: Bool, isPushNotificationActive: Bool = false) {
        self.id = id
        self.totalSeconds = totalSeconds
        self.isAlarmActive = isAlarmActive
        self.isLightActive = isLightActive
        self.isVaibrationActive = isVaibrationActive
        self.isPushNotificationActive = isPushNotificationActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        totalSeconds = try container.decode(Int.self, forKey: .totalSeconds)
        isAlarmActive = try container.decode(Bool.self, forKey: .isAlarmActive)
        isLightActive = try container.decode(Bool.self, forKey: .isLightActive)
        isVaibrationActive = try container.decode(Bool.self, forKey: .isVaibrationActive)
        isPushNotificationActive = try container.decodeIfPresent(Bool.self, forKey: .isPushNotificationActive) ?? false
    }
}

struct ContentView: View {
    
    @State private var SoundVolume:Double = 7

    @State private var isPause:Bool = false
    @State private var isAlarmActive:Bool = false
    @State private var isLightActive:Bool = false
    @State private var isVaibrationActive:Bool = false
    @State private var isPushNotificationActive:Bool = false
    @State private var isTimerActive:Bool = false
    @State private var ButtonName = "START"
    
    
    /*test_make*/
    @State private var minutes: String = ""  // 分の入力フィールドの値
    @State private var seconds: String = ""  // 秒の入力フィールドの値
    @State private var totalTime: Double = 0.0    // 合計の秒数
    @State private var timerActive = false   // タイマーが動作中かどうか
    @State private var timer: Timer?         // タイマーオブジェクト
    @State private var alarmActionTimer: Timer? // タイムアップ処理用タイマー
    @State private var timeString = "10:00"  // ラベルに表示するカウントダウンの文字列
    @State private var timeString_min = "00"
    @State private var timeString_sec = "00"
    @State private var timeString_msec = "00"

    // バックグラウンド復帰時にも正しい残り時間を再計算するための、
    // タイムアップの絶対時刻・一時停止時点の残り秒数
    @State private var endDate: Date? = nil
    @State private var remainingAtPause: Double = 0

    @State private var historyList: [TimerHistory] = []
    @State private var showNotificationHelp: Bool = false // 「？」ボタンで通知方法の説明を表示するかどうか

    // 評価ポップアップ（Apple標準）を表示するためのアクション
    @Environment(\.requestReview) private var requestReview
    // タイマー完了後、アラーム停止を待って評価依頼を出すかどうか判定するためのフラグ
    @State private var isReviewPending: Bool = false

    var body: some View {
        let admob_height = CGFloat(50)
        let bounds = UIScreen.main.bounds
        let width = Int(bounds.width)
        let height = Int(bounds.height)-Int(admob_height)
        let item_height = CGFloat(height/100*15)
        let item_width = CGFloat(width/100*23)
        let switch_height = CGFloat(height/100*11)
        let switch_width = CGFloat(width/100*23) // トグルが4つになったため、3つ用の30%から4つ用の23%に変更
        let button_height = CGFloat(height/100*11)
        let button_width = CGFloat(width/100*48)
        
        VStack {
            // タイマー表示
            HStack{
                Text(timeString_min)
                    .frame(height: CGFloat(height/8))
                    .frame(width: CGFloat(width*25/100))
                Text(":")
                    .frame(height: CGFloat(height/8))
                    .frame(width: CGFloat(width*5/100))
                Text(timeString_sec)
                    .frame(height: CGFloat(height/8))
                    .frame(width: CGFloat(width*25/100))
                Text(".")
                    .frame(height: CGFloat(height/8))
                    .frame(width: CGFloat(width*5/100))
                Text(timeString_msec)
                    .frame(height: CGFloat(height/8))
                    .frame(width: CGFloat(width*25/100))
            }
            .font(.system(size:70))
            .bold()
            .foregroundColor(Color(red:60/255, green:60/255, blue:60/255))
            .shadow(color: Color.gray, radius: 5, x: 0, y: 5)
            .padding(.horizontal)
            
            
            HStack{
                Button(action : {
                    Press_10min()
                }){
                    Text("10\nmin")
                }
                .padding()
                .font(.system(size:20))
                .bold()
                .frame(height: item_height )
                .frame(width: item_width )
                .foregroundColor(.white)
                .background(Color(red:60/255, green:60/255, blue:60/255))
                .cornerRadius(10)
                //.shadow(color: Color.black, radius: 5, x: 0, y: 5)
                
                Button(action : {
                    Press_1min()
                }){
                    Text("1\nmin")
                }
                .padding()
                .font(.system(size:20))
                .bold()
                .frame(height: item_height )
                .frame(width: item_width )
                .foregroundColor(.white)
                .background(Color(red:60/255, green:60/255, blue:60/255))
                .cornerRadius(10)
                //.shadow(color: Color.blue, radius: 15, x: 0, y: 5)

                Button(action : {
                    Press_10sec()
                }){
                    Text("10\nsec")
                }
                .padding()
                .font(.system(size:20))
                .bold()
                .frame(height: item_height )
                .frame(width: item_width )
                .foregroundColor(.white)
                .background(Color(red:60/255, green:60/255, blue:60/255))
                .cornerRadius(10)
                //.shadow(color: Color.blue, radius: 15, x: 0, y: 5)

                Button(action : {
                    Press_1sec()
                }){
                    Text("1\nsec")
                }
                .padding()
                .font(.system(size:20))
                .bold()
                .frame(height: item_height )
                .frame(width: item_width )
                .foregroundColor(.white)
                .background(Color(red:60/255, green:60/255, blue:60/255))
                .cornerRadius(10)
                //.shadow(color: Color.blue, radius: 15, x: 0, y: 5)
            }
            .padding(.vertical)
            
            
            HStack{
                Button(action : {
                    Switch_alarm()
                }){
                    Image(systemName: "alarm.fill")
                }
                .padding()
                .font(.title)
                .bold()
                .frame(height: switch_height )
                .frame(width: switch_width )
                .foregroundColor(.white)
                .background(isAlarmActive ? Color.blue: Color.gray)
                .cornerRadius(15)
                .shadow(color:isAlarmActive ? Color.blue : Color.gray, radius: 15, x: 0, y: 5)

                Button(action : {
                    Switch_light()
                }){
                    Image(systemName: "lightbulb.fill")
                }
                .padding()
                .font(.title)
                .bold()
                .frame(height: switch_height )
                .frame(width: switch_width )
                .foregroundColor(.white)
                .background(isLightActive ? Color.blue : Color.gray)
                .cornerRadius(15)
                .shadow(color:isLightActive ? Color.blue : Color.gray, radius: 15, x: 0, y: 5)

                Button(action : {
                    Switch_vaibration()
                }){
                    Image(systemName: "iphone.homebutton.radiowaves.left.and.right.circle.fill")
                }
                .padding()
                .font(.title)
                .bold()
                .frame(height: switch_height )
                .frame(width: switch_width )
                .foregroundColor(.white)
                .background(isVaibrationActive ? Color.blue : Color.gray)
                .cornerRadius(15)
                .shadow(color:isVaibrationActive ? Color.blue : Color.gray, radius: 15, x: 0, y: 5)

                Button(action : {
                    Switch_pushNotification()
                }){
                    Image(systemName: "bell.badge.fill")
                }
                .padding()
                .font(.title)
                .bold()
                .frame(height: switch_height )
                .frame(width: switch_width )
                .foregroundColor(.white)
                .background(isPushNotificationActive ? Color.blue : Color.gray)
                .cornerRadius(15)
                .shadow(color:isPushNotificationActive ? Color.blue : Color.gray, radius: 15, x: 0, y: 5)

            }
            .padding(.vertical)
            
            HStack{
//                Image(systemName: "speaker.wave.2.circle.fill")
//                    .font(.title)
                Text("Vol. "+"\(Int(SoundVolume))")
                    .font(.system(size:25))
                    .bold()
                    .foregroundColor(.blue)
                    .shadow(color: Color.blue, radius: 15, x: 0, y: 5)
                    .padding()
                Slider(value: $SoundVolume, in: 0...15, step:1){
                    //Text("Volume")
                }
                .padding()
                .onChange(of: SoundVolume, SetVolume)
                    
                Menu {
                    if historyList.isEmpty {
                        Text("履歴なし")
                    } else {
                        ForEach(historyList) { history in
                            Button(action: {
                                ApplyHistory(history)
                            }) {
                                Text(history.displayText)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "list.bullet.rectangle.fill")
                }
                .padding()
                .font(.title3)
                .bold()
                .foregroundColor(.white)
                .background(Color(red:60/255, green:60/255, blue:60/255))
                .cornerRadius(15)
                .onAppear {
                    SetListData()
                }
            }

            HStack{
                Button(action : {
                    StartStopTimer()
                }){
                    Text(ButtonName)
                }
                .padding()
                .font(.system(size:27))
                .bold()
                .frame(height: button_height )
                .frame(width: button_width )
                .foregroundColor(.white)
                .background(isTimerActive ? Color.blue : Color.gray)
                .cornerRadius(15)
                .shadow(color:isTimerActive ? Color.blue : Color.gray, radius: 15, x: 0, y: 5)
                
                Button(action : {
                    ClearTimer()
                }){
                    Text("CLEAR")
                }
                .padding()
                .font(.system(size:27))
                .bold()
                .frame(height: button_height )
                .frame(width: button_width )
                .foregroundColor(.white)
                .background(.red)
                .cornerRadius(15)
                .shadow(color:Color.red, radius: 15, x: 0, y: 5)

                Button(action: {
                    showNotificationHelp = true
                }) {
                    Image(systemName: "questionmark.circle.fill")
                }
                .padding()
                .font(.title3)
                .bold()
                .foregroundColor(.white)
                .background(Color(red:60/255, green:60/255, blue:60/255))
                .cornerRadius(15)

            }

        }
        .padding(.horizontal)
        .onAppear {
            requestNotificationPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            syncOnForeground()
        }
        .sheet(isPresented: $showNotificationHelp) {
            NotificationHelpView()
        }

        Spacer()

        //広告
        BannerAdView()
        //                .frame(width: 320, height: 50)  // バナー広告のサイズ
            .frame(width: AdSizeBanner.size.width, height:
                    AdSizeBanner.size.height)
        //上下予約エリア確保
        Spacer()
            .frame(height: 5)

    }
    
    func Press_10min(){
        if isTimerActive == true {
            return
        }
        var tmp:Int = Int(timeString_min) ?? 0
        tmp = tmp + 10;
        timeString_min = String(format: "%02d", tmp)
    }
    func Press_1min(){
        if isTimerActive == true {
            return
        }
        var tmp:Int = Int(timeString_min) ?? 0
        tmp = tmp + 1;
        timeString_min = String(format: "%02d", tmp)
    }
    func Press_10sec(){
        if isTimerActive == true {
            return
        }
        addSeconds(10)
    }
    func Press_1sec(){
        if isTimerActive == true {
            return
        }
        addSeconds(1)
    }
    // 秒を加算し、60秒以上になった分は繰り上げて分側に反映する
    // （これが無いと「70秒」のような表示になってしまう不具合の原因だった）
    func addSeconds(_ amount: Int) {
        var m = Int(timeString_min) ?? 0
        var s = Int(timeString_sec) ?? 0
        s += amount
        if s >= 60 {
            m += s / 60
            s = s % 60
        }
        timeString_min = String(format: "%02d", m)
        timeString_sec = String(format: "%02d", s)
    }
    func Switch_alarm(){
        if isTimerActive == true {
            return
        }
        if isAlarmActive == true {
            isAlarmActive = false
        }
        else {
            isAlarmActive = true
        }
    }
    func Switch_light(){
        if isTimerActive == true {
            return
        }
        if isLightActive == true {
            isLightActive = false
        }
        else {
            isLightActive = true
        }
    }
    func Switch_vaibration(){
        if isTimerActive == true {
            return
        }
        if isVaibrationActive == true {
            isVaibrationActive = false
        }
        else {
            isVaibrationActive = true
        }

    }
    // タイムアップ時にPUSH通知（ローカル通知）を送るかどうかのオン/オフ
    func Switch_pushNotification(){
        if isTimerActive == true {
            return
        }
        if isPushNotificationActive == true {
            isPushNotificationActive = false
        }
        else {
            isPushNotificationActive = true
        }
    }
    func SetListData() {
        if let data = UserDefaults.standard.data(forKey: "TimerHistoryList"),
           let decoded = try? JSONDecoder().decode([TimerHistory].self, from: data) {
            historyList = decoded
        }
    }
    
    func SaveHistoryData(totalSeconds: Int) {
        if totalSeconds <= 0 { return }
        let newHistory = TimerHistory(
            totalSeconds: totalSeconds,
            isAlarmActive: isAlarmActive,
            isLightActive: isLightActive,
            isVaibrationActive: isVaibrationActive,
            isPushNotificationActive: isPushNotificationActive
        )

        // 同じ設定内容があれば削除して先頭に追加し直す
        historyList.removeAll { $0.totalSeconds == newHistory.totalSeconds && $0.isAlarmActive == newHistory.isAlarmActive && $0.isLightActive == newHistory.isLightActive && $0.isVaibrationActive == newHistory.isVaibrationActive && $0.isPushNotificationActive == newHistory.isPushNotificationActive }

        historyList.insert(newHistory, at: 0)

        // 最大10件まで保持
        if historyList.count > 10 {
            historyList = Array(historyList.prefix(10))
        }

        if let encoded = try? JSONEncoder().encode(historyList) {
            UserDefaults.standard.set(encoded, forKey: "TimerHistoryList")
        }
    }

    func ApplyHistory(_ history: TimerHistory) {
        if isTimerActive { return } // 動作中は反映しない

        let m = history.totalSeconds / 60
        let s = history.totalSeconds % 60
        timeString_min = String(format: "%02d", m)
        timeString_sec = String(format: "%02d", s)
        timeString_msec = "00"

        isAlarmActive = history.isAlarmActive
        isLightActive = history.isLightActive
        isVaibrationActive = history.isVaibrationActive
        isPushNotificationActive = history.isPushNotificationActive
    }
    func SetVolume(){
        // Sliderの値(0~15)を0.0~1.0の範囲に変換
        AlarmPlayer.shared.setVolume(Float(SoundVolume) / 15.0)
    }
    func StartStopTimer(){
        alarmActionTimer?.invalidate()
        turnOffLight()
        AlarmPlayer.shared.stop()

        if isTimerActive == true {
//            isTimerActive = false
            if isPause == true {
                ButtonName = "STOP"
                //再開
                startTimer()
                isPause = false
            }
            else {
                ButtonName = "START"
                // 一時停止（残り時間を保存し、通知もキャンセルする）
                timer?.invalidate()
                remainingAtPause = max(0, endDate?.timeIntervalSinceNow ?? 0)
                cancelEndNotification()
                isPause = true
            }
        }
        else {
            isTimerActive = true
            ButtonName = "STOP"
            startTimer()
        }

        // タイムアップ後にボタンでアラームを止めた場合は、評価依頼の条件を判定する
        // （新しいタイマーを開始した場合は邪魔にならないよう表示しない）
        if !isTimerActive {
            requestReviewIfNeeded()
        }
    }
    func ClearTimer(){
        isTimerActive = false
        ButtonName = "START"
        alarmActionTimer?.invalidate()
        turnOffLight()
        resetTimer()
        // タイムアップ後にCLEARでアラームを止めた場合は、評価依頼の条件を判定する
        requestReviewIfNeeded()
    }

    // タイマーをスタートするメソッド
    // 「経過時間を毎回引き算していく」方式だと、バックグラウンドで
    // Timerが止まっている間は一切カウントが進まず、フォアグラウンドに
    // 戻った瞬間から再開する（＝止まって見える）という不具合があった。
    // これを解消するため、「終了予定時刻（endDate）」を絶対時刻として保持し、
    // 表示のたびに endDate との差分から残り時間を計算する方式に変更した。
    // これによりアプリがサスペンドされていた間の経過時間も、
    // 復帰時に正しく反映できる。
    func startTimer() {
        // 既存のタイマーがあれば無効化
        timer?.invalidate()

        let remaining: Double
        if isPause {
            // 一時停止からの再開
            remaining = remainingAtPause
        } else {
            // 新規スタート
            let t_min:Int = Int(timeString_min) ?? 0
            let t_sec:Int = Int(timeString_sec) ?? 0
            totalTime = Double(t_min * 60 + t_sec)
            if totalTime <= 0 {
                isTimerActive = false
                ButtonName = "START"
                return
            }
            SaveHistoryData(totalSeconds: Int(totalTime))
            remaining = totalTime
        }

        endDate = Date().addingTimeInterval(remaining)
        // アプリがバックグラウンド/サスペンド状態でも時間になったら
        // 通知でお知らせできるよう、ローカル通知を予約しておく
        scheduleEndNotification(after: remaining)

        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in  // 10msごとに更新
            guard let end = endDate else { return }
            let rem = end.timeIntervalSinceNow

            // iOSはアプリをバックグラウンドに回した直後の数十秒間、処理を続行させることがあり、
            // その間にこのTimerがまだ生きていて発火してしまう場合がある。
            // その状態で finishTimer() を呼ぶと、
            //  ・PUSH通知をキャンセルしてしまう（cancelEndNotification）
            //  ・音声(AVAudioPlayer)やライト(カメラ)はバックグラウンドでは正常に動作できない
            // ため、「バイブだけ鳴ってPUSH通知が来ない」という中途半端な状態になっていた。
            // これを防ぐため、実際にフォアグラウンド（アクティブ）状態の時だけ
            // タイムアップ処理を行い、バックグラウンド中はPUSH通知に任せる。
            guard UIApplication.shared.applicationState == .active else {
                if rem <= 0 {
                    timer?.invalidate() // このTimerは役目を終える。後始末はフォアグラウンド復帰時のsyncOnForeground()が行う
                }
                return
            }

            if rem > 0 {
                timeString = formatTime(rem)
            } else {
                finishTimer()
            }
        }
    }

    // タイムアップ時（フォアグラウンドでカウントが0になった時、
    // または復帰時に時間切れを検知した時）にまとめて呼ぶ後始末処理
    func finishTimer() {
        timer?.invalidate()
        cancelEndNotification()
        isTimerActive = false
        isPause = false
        totalTime = 0
        remainingAtPause = 0
        endDate = nil
        ButtonName = "START"
        timeString_min = "00"
        timeString_sec = "00"
        timeString_msec = "00"
        timeUpAction()

        // タイマー完了回数を記録し、アラーム停止後に評価依頼を判定する
        ReviewManager.recordTimerCompletion()
        isReviewPending = true
        // アラーム・ライト・バイブがすべてOFFなら止める操作が無いため、少し待ってから判定する
        if !isAlarmActive && !isLightActive && !isVaibrationActive {
            requestReviewIfNeeded(delay: 1.5)
        }
    }

    // タイマー完了後、条件を満たしていれば評価ポップアップを表示する。
    // アラームが鳴っている最中に出すと操作の邪魔になるため、
    // アラームを止めた（または自動停止した）後に呼び出す。
    func requestReviewIfNeeded(delay: Double = 0.8) {
        guard isReviewPending else { return }
        isReviewPending = false
        guard ReviewManager.shouldRequestReview() else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 待っている間に新しいタイマーが開始された／アプリが閉じられた場合は出さない
            guard !isTimerActive, UIApplication.shared.applicationState == .active else { return }
            ReviewManager.markRequested()
            requestReview()
        }
    }

    // タイマーをリセットするメソッド
    func resetTimer() {
        isTimerActive = false
        isPause = false
        timer?.invalidate()
        alarmActionTimer?.invalidate()
        turnOffLight()
        AlarmPlayer.shared.stop()
        cancelEndNotification()
        totalTime = 0
        remainingAtPause = 0
        endDate = nil
        ButtonName = "START"
        timeString_min = "00"
        timeString_sec = "00"
        timeString_msec = "00"

    }

    // アプリがフォアグラウンドに戻った時に呼ばれる。
    // バックグラウンド中はTimerが動いていないため、endDateとの差分から
    // 正しい残り時間を計算し直し、既に時間切れならその場でタイムアップ処理を行う。
    func syncOnForeground() {
        guard isTimerActive, !isPause, let end = endDate else { return }
        let rem = end.timeIntervalSinceNow
        if rem > 0 {
            timeString = formatTime(rem)
        } else {
            finishTimer()
        }
    }

    // MARK: - ローカル通知（バックグラウンド/画面ロック中のお知らせ用）

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                print("通知の許可取得に失敗しました: \(error)")
            }
        }
    }

    func scheduleEndNotification(after seconds: Double) {
        cancelEndNotification()
        // トグルがOFFの場合はPUSH通知を予約しない
        guard isPushNotificationActive else { return }
        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "NoticeTimer"
        content.body = "設定した時間になりました"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 0.1), repeats: false)
        let request = UNNotificationRequest(identifier: "NoticeTimerEnd", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelEndNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["NoticeTimerEnd"])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["NoticeTimerEnd"])
    }
    
    // 残り時間を秒・ミリ秒形式でフォーマットするメソッド
    func formatTime(_ totalSeconds: Double) -> String {
        let minutes = Int(totalSeconds) / 60
        let seconds = totalSeconds.truncatingRemainder(dividingBy: 60)
        let seconds_1 = Int(seconds)
        let seconds_2 = Int(seconds * 100) % 100
        
        timeString_min = String(format: "%02d", minutes)
        timeString_sec = String(format: "%02d", seconds_1)
        timeString_msec = String(format: "%02d", seconds_2)

        
        return String(format: "%02d:%02d:%02d", minutes, seconds_1, seconds_2)
//org        return String(format: "%02d:%05.2f", minutes, seconds)
    }
    
    // MARK: - Notification Actions

    // タイムアップ処理
    func timeUpAction() {
        alarmActionTimer?.invalidate()
        var fireCount = 0
        
        // 0.5秒おきに通知処理を実行
        alarmActionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            fireCount += 1
            
            // 120回（60秒間）で自動停止
            if fireCount > 120 {
                timer.invalidate()
                turnOffLight()
                AlarmPlayer.shared.stop()
                // アラームが自動停止した後に評価依頼の条件を判定する
                requestReviewIfNeeded(delay: 1.0)
                return
            }
            
            // アラーム（最初の1回目で再生を開始し、あとはループさせる）
            if isAlarmActive && fireCount == 1 {
                playAlarm()
            }
            
            // バイブレーション
            if isVaibrationActive && fireCount % 2 == 1 {
                vibrate()
            }
            
            // ライト点滅 (奇数回でオン、偶数回でオフ)
            if isLightActive {
                toggleLight(isOn: fireCount % 2 == 1)
            }
        }
    }
    
    // アラームを鳴らす処理
    func playAlarm() {
        // 用意いただいた音源をループ再生（マナーモード貫通）
        AlarmPlayer.shared.play()
    }
    
    // バイブレーションする処理
    func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    // ライト点滅する処理のON/OFF
    func toggleLight(isOn: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }
    
    // ライトを完全に消す処理
    func turnOffLight() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if device.torchMode != .off {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }
}

// フォアグラウンド／バックグラウンドで通知の出し方が異なることを説明するヘルプ画面
// （「？」ボタンから開く）
struct NotificationHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("通知についてのご案内")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }

            Text("タイムアップ時のお知らせ方法は、アプリの状態によって自動的に切り替わります。")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpSection(
                        icon: "iphone",
                        title: "アプリを開いている時",
                        text: "アラーム・ライト・バイブのスイッチがONになっている項目について、音・光・振動でお知らせします。このときPUSH通知のバナーは表示されません（二重に鳴らさないためです）。"
                    )

                    helpSection(
                        icon: "bell.badge.fill",
                        title: "アプリを閉じている時",
                        text: "音・ライト・バイブはiOSの仕組み上、アプリが閉じている間は動作できません。そのため代わりにPUSH通知でお知らせします。通知をタップしてアプリを開くと、アラーム・ライト・バイブが続けて再生されます。"
                    )

                    Text("※ PUSH通知でお知らせするには、画面の「PUSH通知」スイッチをONにし、端末の通知を許可しておく必要があります。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }

            Spacer(minLength: 0)
        }
        .padding()
    }

    @ViewBuilder
    private func helpSection(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
