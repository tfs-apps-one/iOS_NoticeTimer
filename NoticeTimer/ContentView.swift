//
//  ContentView.swift
//  NoticeTimer
//
//  Created by 古川貴史 on 2024/10/13.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    
    @State private var SoundVolume:Double = 0

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
    @State private var timeString = "10:00"  // ラベルに表示するカウントダウンの文字列
    @State private var timeString_min = "00"
    @State private var timeString_sec = "00"
    @State private var timeString_msec = "00"

    var body: some View {
        
        let admob_height = CGFloat(50)
        let bounds = UIScreen.main.bounds
        let width = Int(bounds.width)
        let height = Int(bounds.height)-Int(admob_height)
        let item_height = CGFloat(height/100*15)
        let item_width = CGFloat(width/100*23)
        let switch_height = CGFloat(height/100*15)
        let switch_width = CGFloat(width/100*30)
        let button_height = CGFloat(height/100*15)
        let button_width = CGFloat(width/100*45)
        
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
            .foregroundColor(.gray)
            .shadow(color: Color.gray, radius: 15, x: 0, y: 5)
            .padding(.horizontal)
            
            
            HStack{
                Button(action : {
                    Press_10min()
                }){
                    Text("10\nmin")
                }
                .padding()
                .font(.title3)
                .bold()
                .frame(height: item_height )
                .frame(width: item_width )
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)
                .shadow(color: Color.blue, radius: 15, x: 0, y: 5)
                
                Button(action : {
                    Press_1min()
                }){
                    Text("1\nmin")
                }
                .padding()
                .font(.title3)
                .bold()
                .frame(height: item_height )
                .frame(width: item_width )
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)
                .shadow(color: Color.blue, radius: 15, x: 0, y: 5)

                Button(action : {
                    Press_10sec()
                }){
                    Text("10\nsec")
                }
                .padding()
                .font(.title3)
                .bold()
                .frame(height: item_height )
                .frame(width: item_width )
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)
                .shadow(color: Color.blue, radius: 15, x: 0, y: 5)

                Button(action : {
                    Press_1sec()
                }){
                    Text("1\nsec")
                }
                .padding()
                .font(.title3)
                .bold()
                .frame(height: item_height )
                .frame(width: item_width )
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)
                .shadow(color: Color.blue, radius: 15, x: 0, y: 5)
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
                .background(isAlarmActive ? Color.blue : Color.gray)
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
                    .font(.title)
                    .bold()
                    .foregroundColor(.blue)
                    .shadow(color: Color.blue, radius: 15, x: 0, y: 5)
                    .padding()
                Slider(value: $SoundVolume, in: 0...15, step:1){
                    //Text("Volume")
                }
                .padding()
                .onChange(of: SoundVolume, SetVolume)
                
            }
            
            HStack{
                Button(action : {
                    StartStopTimer()
                }){
                    Text(ButtonName)
                }
                .padding()
                .font(.title)
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
                .font(.title)
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
    func SetVolume(){
        
    }
    func StartStopTimer(){
        
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
               resetTimer()
//               timer?.invalidate()
//               isTimerActive = false
//               timeString_min = "00"
//               timeString_sec = "00"
//               timeString_msec = "00"
           }
        }
    }

    // タイマーをリセットするメソッド
    func resetTimer() {
        isTimerActive = false
        isPause = false
        timer?.invalidate()
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
}

#Preview {
    ContentView()
}
