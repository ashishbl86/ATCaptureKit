import AVFoundation

enum IDCCaptureSound {

    private static let player: AVAudioPlayer? = {
        guard let url = Bundle.module.url(forResource: "scanSuccess", withExtension: "mp3"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }()

    static func play() {
        player?.currentTime = 0
        player?.play()
    }
}
