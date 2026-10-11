//
//  NoticeTimerApp.swift
//  NoticeTimer
//
//  Created by 古川貴史 on 2024/10/13.
//

import SwiftUI
import AVFoundation
import UserNotifications
import GoogleMobileAds


@main
struct NoticeTimerApp: App {
    init (){
        setupAudioSession()
        // 評価ポップアップ表示判定のため、起動回数と初回起動日を記録
        ReviewManager.recordAppLaunch()
        // バックグラウンド/画面ロック中でもタイムアップ通知を出すための
        // ローカル通知デリゲートを、起動時点で確実に登録しておく
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
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
