//
//  GameView.swift
//  Charades
//
//  Created by Menelik Eyasu on 7/21/24.
//

import SwiftUI
import CoreMotion

struct GameView: View {
    @Environment(\.dismiss) var dismiss
    @State private var viewModel = ViewModel()

    var body: some View {
        VStack {
            if viewModel.playing {
                if viewModel.showSuccess {
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .frame(width: 50, height: 50)
                }

                if viewModel.showFailed {
                    Image(systemName: "xmark.circle")
                        .resizable()
                        .frame(width: 50, height: 50)
                }

                if let word = viewModel.getSelectedWord() {
                    Text(word)
                        .font(.custom("Helvetica", size: 50))
                        .foregroundStyle(.white)
                }

                Text(viewModel.timeString)
                    .font(.custom("Helvetica", size: 25))
            } else {
                Text("You got \(viewModel.correct) right!")
                ForEach(viewModel.words, id: \.self) { word in
                    Text(word.value)
                        .foregroundStyle(.white)
                        .opacity(word.guessedRight ? 1.0 : 0.7)
                }

                 Text("Play Again")
                    .foregroundStyle(.white)
                    .onTapGesture { self.dismiss() }
            }
        }.navigationBarHidden(true)
         .rotationEffect(viewModel.playing ? .degrees(90) : .zero)
         .onReceive(viewModel.timer) { _ in viewModel.updateTimer() }
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         .background(viewModel.showSuccess ? .green : viewModel.showFailed ? .red : .blue)
         .edgesIgnoringSafeArea(.all)
         .onAppear { viewModel.startGame() }
    }

    init(_ duration: Int, _ words: [Word]) {
        viewModel.populate(duration, words)
        if viewModel.words.isEmpty {
            self.dismiss()
        }
    }
}

extension GameView {
    struct GameWord: Hashable {
        let value: String
        var guessedRight: Bool
    }

    @Observable
    class ViewModel {
        let motion = CMMotionManager()
        var angle: Double = 0

        var selected: Int = 0
        var words: [GameWord] = []
        var playing = true
        var correct: Int = 0

        var showSuccess = false
        var showFailed = false

        var duration: TimeInterval = 5 * 60
        let timer = Timer.publish(
            every: 1,
            on: .main,
            in: .common
        ).autoconnect()
        var endTime = Date()
        var timeString = "---"
        let timerFormat = DateComponentsFormatter()

        init() {
            self.timerFormat.allowedUnits = [.minute, .second]
            self.timerFormat.unitsStyle = .abbreviated
            self.timerFormat.zeroFormattingBehavior = .dropLeading
        }

        func populate(_ duration: Int, _ words: [Word]) {
            self.duration = TimeInterval(duration)
            for wordEntity in words {
                if let word = wordEntity.value {
                    self.words.append(GameWord(
                        value: word,
                        guessedRight: false
                    ))
                }
            }
        }

        func getSelectedWord() -> String? {
            if self.words.indices.contains(self.selected) {
                return self.words[self.selected].value
            }
            return nil
        }

        func startGame() {
            self.endTime = Date().addingTimeInterval(self.duration)

            if self.motion.isAccelerometerAvailable {
                self.motion.startAccelerometerUpdates(to: OperationQueue.main) { data, error in
                    if let acc = data?.acceleration {
                        if abs(acc.y) > 0.2 || self.showSuccess || self.showFailed {
                        } else if self.angle <= 0.7 && acc.z > 0.7 {
                            self.success()
                        } else if self.angle >= -0.7 && acc.z < -0.7 {
                            self.failed()
                        }

                        self.angle = acc.z
                    }
                }
            }
        }

        func updateTimer() {
            let delta = self.endTime.timeIntervalSince(Date())
            if delta <= 0 {
                self.playing = false
                self.motion.stopAccelerometerUpdates()
            }

            if let timeLeft = self.timerFormat.string(from: delta) {
                self.timeString = timeLeft
            }
        }

        func advance() {
            self.selected += 1
            if !self.words.indices.contains(self.selected) {
                self.playing = false
                self.motion.stopAccelerometerUpdates()
            }
        }

        func success() {
            self.words[selected].guessedRight = true
            self.correct += 1

            self.showSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.showSuccess = false
                self.advance()
            }
        }

        func failed() {
            self.showFailed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.showFailed = false
                self.advance()
            }
        }
    }
}
