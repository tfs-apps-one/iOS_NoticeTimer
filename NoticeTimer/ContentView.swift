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
import GoogleMobileAds


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
    
    var displayText: String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        let alarmStr = isAlarmActive ? "◼︎" : "◻︎"
        let lightStr = isLightActive ? "◼︎" : "◻︎"
        let vibStr = isVaibrationActive ? "◼︎" : "◻︎"
        return String(format: "%02d:%02d.00  %@_%@_%@", m, s, alarmStr, lightStr, vibStr)
    }
}

struct ContentView: View {
    
    @State private var SoundVolume:Double = 7

    @State private var isPause:Bool = false
    @State private var isAlarmActive:Bool = false
    @State private var isLightActive:Bool = false
    @State private var isVaibrationActive:Bool = false
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
    
    @State private var historyList: [TimerHistory] = []

    var body: some View {
        let admob_height = CGFloat(50)
        let bounds = UIScreen.main.bounds
        let width = Int(bounds.width)
        let height = Int(bounds.height)-Int(admob_height)
        let item_height = CGFloat(height/100*15)
        let item_width = CGFloat(width/100*23)
        let switch_height = CGFloat(height/100*11)
        let switch_width = CGFloat(width/100*30)
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

            }
            
        }
        .padding(.horizontal)

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
        timeString_min = String(tmp)
        
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
        var tmp:Int = Int(timeString_sec) ?? 0
        tmp = tmp + 10;
        timeString_sec = String(tmp)

    }
    func Press_1sec(){
        if isTimerActive == true {
            return
        }
        var tmp:Int = Int(timeString_sec) ?? 0
        tmp = tmp + 1;
        timeString_sec = String(format: "%02d", tmp)
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
            isVaibrationActive: isVaibrationActive
        )
        
        // 同じ設定内容があれば削除して先頭に追加し直す
        historyList.removeAll { $0.totalSeconds == newHistory.totalSeconds && $0.isAlarmActive == newHistory.isAlarmActive && $0.isLightActive == newHistory.isLightActive && $0.isVaibrationActive == newHistory.isVaibrationActive }
        
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
                // 一時停止
                timer?.invalidate()
                isPause = true
            }
        }
        else {
            isTimerActive = true
            ButtonName = "STOP"
            startTimer()
        }
    }
    func ClearTimer(){
        isTimerActive = false
        ButtonName = "START"
        alarmActionTimer?.invalidate()
        turnOffLight()
        resetTimer()
    }

    // タイマーをスタートするメソッド
    func startTimer() {
        let t_min:Int = Int(timeString_min) ?? 0
        let t_sec:Int = Int(timeString_sec) ?? 0
        
        // 既存のタイマーがあれば無効化
        timer?.invalidate()
       
        // タイマーを開始
//        isTimerActive = true
        if totalTime == 0 {
            totalTime = Double(t_min * 60 + t_sec)
            SaveHistoryData(totalSeconds: Int(totalTime))
        }
        if totalTime <= 0 {
            isTimerActive = false
            ButtonName = "START"
            return
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in  // 10msごとに更新
           if totalTime > 0 {
               totalTime -= 0.01
               timeString = formatTime(totalTime)
           } else {
               timer?.invalidate()
               isTimerActive = false
               isPause = false
               totalTime = 0
               ButtonName = "START"
               timeString_min = "00"
               timeString_sec = "00"
               timeString_msec = "00"
               timeUpAction()
           }
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
        totalTime = 0
        ButtonName = "START"
        timeString_min = "00"
        timeString_sec = "00"
        timeString_msec = "00"

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

#Preview {
    ContentView()
}
