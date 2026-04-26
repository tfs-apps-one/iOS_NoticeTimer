//
//  NoticeTimerApp.swift
//  NoticeTimer
//
//  Created by 古川貴史 on 2024/10/13.
//

import SwiftUI
import AVFoundation
import GoogleMobileAds


@main
struct NoticeTimerApp: App {
    init (){
        setupAudioSession()
        //広告初期化
        //GADMobileAds.sharedInstance().start(completionHandler: nil)
        //MobileAds.sharedInstance().start(completionHandler: nil)
        MobileAds.shared.start(completionHandler: { _ in })
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
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
