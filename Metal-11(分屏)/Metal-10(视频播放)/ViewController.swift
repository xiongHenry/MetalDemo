//
//  ViewController.swift
//  Metal-10(视频播放)
//
//  Created by 熊涛 on 2019/12/11.
//  Copyright © 2019 xiong_tao. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    var movie: XTVideoMovie?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.addSubview(staticBtn)
        view.addSubview(dynamicBtn)
        staticBtn.frame = CGRect(x: view.bounds.width*0.5 - 150, y: view.bounds.height - 150, width: 100, height: 50)
        dynamicBtn.frame = CGRect(x: view.bounds.width*0.5 + 50, y: view.bounds.height - 150, width: 100, height: 50)
    }

    @objc func staticButtonClicked() {
        present(StaticSplitScreenViewController(), animated: true, completion: nil)
    }
    
    @objc func dynamicButtonClicked() {
        present(DynamicSplitScreenViewController(), animated: true, completion: nil)
    }
    
    // MARK: - lazy
    lazy var staticBtn: UIButton = {
        let b = UIButton()
        b.backgroundColor = .red
        b.setTitleColor(.white, for: .normal)
        b.setTitle("static", for: .normal)
        b.addTarget(self, action: #selector(staticButtonClicked), for: .touchUpInside)
        return b
    }()
    
    lazy var dynamicBtn: UIButton = {
        let b = UIButton()
        b.backgroundColor = .red
        b.setTitleColor(.white, for: .normal)
        b.setTitle("dynamic", for: .normal)
        b.addTarget(self, action: #selector(dynamicButtonClicked), for: .touchUpInside)
        return b
    }()
}

