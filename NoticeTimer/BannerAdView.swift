//
//  Banner.swift
//  NoticeTimer
//
//  Created by 古川貴史 on 2026/04/25.
//
import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
    #if false //test_make
        let viewController = UIViewController()
    #else
        let viewController = UIViewController()
        let banner = BannerView(adSize: AdSizeBanner)
        
//        banner.adUnitID = "ca-app-pub-3940256099942544/2435281174"  //テスト広告
        banner.adUnitID = "ca-app-pub-4924620089567925/9883916458"  //本番 ここにあなたの広告ユニットIDを入れます
        banner.rootViewController = viewController
        
        viewController.view.addSubview(banner)
        
        banner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
        
        banner.load(Request())
    #endif
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}

