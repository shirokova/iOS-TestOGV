//
//  ViewController.swift
//  testOGV
//
//  Created by Anna Shirokova on 29/10/15.
//
//

import UIKit

class ViewController: UIViewController, OGVPlayerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        test()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    func test () {
        
        let playerView = OGVPlayerView(frame: view.bounds)
        view.addSubview(playerView)
        
        playerView.delegate = self; // implement OGVPlayerDelegate protocol
        playerView.sourceURL = NSURL(string: "http://video.webmfiles.org/big-buck-bunny_trailer.webm")
     
        playerView.play()
    }
}

