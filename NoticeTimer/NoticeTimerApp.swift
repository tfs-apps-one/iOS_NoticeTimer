//
//  NoticeTimerApp.swift
//  NoticeTimer
//
//  Created by 古川貴史 on 2024/10/13.
//

import SwiftUI
import AVFoundation


@main
struct NoticeTimerApp: App {
    init (){
        setupAudioSession()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

func setupAudioSession() {
    do {
        // オーディオセッションのインスタンスを取得
        let audioSession = AVAudioSession.sharedInstance()
        // バックグラウンドで音声再生を続けるためのカテゴリを設定
        try audioSession.setCategory(.playback, mode: .default, options: [])
        // オーディオセッションをアクティブ化
        try audioSession.setActive(true)
    } catch {
        print("Error: Could not set up audio session.")
    }
}
