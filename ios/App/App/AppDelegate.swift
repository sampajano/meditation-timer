import UIKit
import SwiftUI
import AVFoundation
import OSLog

private let maxMeditationTime: TimeInterval = 60 * 60
private let defaultMeditationTime: TimeInterval = 20 * 60
private let defaultCountdownDuration: TimeInterval = 15
private let maxCountdownDuration: TimeInterval = 60
private let defaultIntervalCount = 2
private let startGongVolume: Float = 0.8
private let intervalGongVolume: Float = 0.20
private let liveActivityLog = Logger(subsystem: "com.lukex.goldenmeditation", category: "LiveActivity")
private let liveActivityDebugLogLock = NSLock()

func appendLiveActivityDebugLog(_ message: String) {
    liveActivityDebugLogLock.lock()
    defer { liveActivityDebugLogLock.unlock() }

    guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return
    }

    let url = directory.appendingPathComponent("live-activity-debug.log")
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "\(timestamp) \(message)\n"

    guard let data = line.data(using: .utf8) else { return }

    if !FileManager.default.fileExists(atPath: url.path) {
        FileManager.default.createFile(atPath: url.path, contents: nil)
    }

    do {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    } catch {
        print("Failed to append Live Activity debug log: \(error)")
    }
}

private struct MeditationPreferences {
    private enum Key {
        static let totalTime = "meditation.preferences.totalTime"
        static let intervalInputMode = "meditation.preferences.intervalInputMode"
        static let intervalCount = "meditation.preferences.intervalCount"
        static let intervalX = "meditation.preferences.intervalX"
        static let isCountdownEnabled = "meditation.preferences.isCountdownEnabled"
        static let countdownDuration = "meditation.preferences.countdownDuration"
    }

    var totalTime: TimeInterval
    var intervalInputMode: String
    var intervalCount: Int
    var intervalX: TimeInterval
    var isCountdownEnabled: Bool
    var countdownDuration: TimeInterval

    static var appDefault: MeditationPreferences {
        MeditationPreferences(
            totalTime: defaultMeditationTime,
            intervalInputMode: "count",
            intervalCount: defaultIntervalCount,
            intervalX: defaultMeditationTime / Double(defaultIntervalCount),
            isCountdownEnabled: false,
            countdownDuration: defaultCountdownDuration
        )
    }

    static func load(from defaults: UserDefaults = .standard) -> MeditationPreferences {
        var preferences = appDefault

        if defaults.object(forKey: Key.totalTime) != nil {
            preferences.totalTime = defaults.double(forKey: Key.totalTime)
        }

        if let mode = defaults.string(forKey: Key.intervalInputMode), mode == "time" || mode == "count" {
            preferences.intervalInputMode = mode
        }

        if defaults.object(forKey: Key.intervalCount) != nil {
            preferences.intervalCount = defaults.integer(forKey: Key.intervalCount)
        }

        if defaults.object(forKey: Key.intervalX) != nil {
            preferences.intervalX = defaults.double(forKey: Key.intervalX)
        }

        if defaults.object(forKey: Key.isCountdownEnabled) != nil {
            preferences.isCountdownEnabled = defaults.bool(forKey: Key.isCountdownEnabled)
        }

        if defaults.object(forKey: Key.countdownDuration) != nil {
            preferences.countdownDuration = defaults.double(forKey: Key.countdownDuration)
        }

        return preferences.normalized()
    }

    func save(to defaults: UserDefaults = .standard) {
        let preferences = normalized()
        defaults.set(preferences.totalTime, forKey: Key.totalTime)
        defaults.set(preferences.intervalInputMode, forKey: Key.intervalInputMode)
        defaults.set(preferences.intervalCount, forKey: Key.intervalCount)
        defaults.set(preferences.intervalX, forKey: Key.intervalX)
        defaults.set(preferences.isCountdownEnabled, forKey: Key.isCountdownEnabled)
        defaults.set(preferences.countdownDuration, forKey: Key.countdownDuration)
    }

    func normalized() -> MeditationPreferences {
        let roundedMinutes = max(1, min(Int(maxMeditationTime / 60), Int(round(totalTime / 60))))
        let normalizedTotal = TimeInterval(roundedMinutes * 60)
        let normalizedMode = intervalInputMode == "time" ? "time" : "count"
        let maxSectionCount = max(1, Int(normalizedTotal / 5))
        let normalizedCountdown = max(3, min(maxCountdownDuration, countdownDuration))

        if normalizedMode == "time" {
            let intervalMinutes = max(1, Int(round(intervalX / 60)))
            let normalizedInterval = min(normalizedTotal, TimeInterval(intervalMinutes * 60))
            return MeditationPreferences(
                totalTime: normalizedTotal,
                intervalInputMode: normalizedMode,
                intervalCount: max(1, Int(round(normalizedTotal / normalizedInterval))),
                intervalX: normalizedInterval,
                isCountdownEnabled: isCountdownEnabled,
                countdownDuration: normalizedCountdown
            )
        }

        let normalizedCount = min(maxSectionCount, max(1, intervalCount))
        return MeditationPreferences(
            totalTime: normalizedTotal,
            intervalInputMode: normalizedMode,
            intervalCount: normalizedCount,
            intervalX: normalizedTotal / Double(normalizedCount),
            isCountdownEnabled: isCountdownEnabled,
            countdownDuration: normalizedCountdown
        )
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let contentView = MeditationAppView()
        
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

}

// MARK: - Native Background Timer Helper

class BackgroundTimer: ObservableObject {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.goldenmeditation.timer", qos: .userInteractive)
    
    var onTick: (() -> Void)?
    
    func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 1.0)
        t.setEventHandler {
            DispatchQueue.main.async {
                self.onTick?()
            }
        }
        t.resume()
        self.timer = t
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
    }
}

// MARK: - Native SwiftUI Application UI

struct MeditationAppView: View {
    // Session State
    @State private var totalTime: TimeInterval = defaultMeditationTime
    @State private var timeLeft: TimeInterval = defaultMeditationTime
    @State private var isRunning = false
    
    // Absolute Time Tracking State for flawless background running
    @State private var sessionStartTime: Date? = nil
    @State private var accumulatedElapsed: TimeInterval = 0
    @State private var lastProcessedSecond: Int = 0
    @State private var overtimeActive = false
    @State private var overtimeStartTime: Date? = nil
    @State private var overtimeAccumulated: TimeInterval = 0
    @State private var overtimeElapsed: TimeInterval = 0
    
    // Interval State
    @State private var intervalX: TimeInterval = 10 * 60
    @State private var isCustomInterval = false
    @State private var intervalInputMode = "count" // Default is 'count'
    @State private var intervalCount: Int = defaultIntervalCount // Persistent section count state
    
    // Countdown State
    @State private var isCountdownEnabled = false
    @State private var countdownDuration: TimeInterval = defaultCountdownDuration
    @State private var countdownActive = false
    @State private var countdownTimeLeft: TimeInterval = defaultCountdownDuration
    
    // Bottom Sheet Visibility
    @State private var showSettings = false
    @GestureState private var settingsDragOffset: CGFloat = 0
    
    // Text Inputs (synchronized with values on commit/blur)
    @State private var totalMinsInput = "20"
    @State private var intervalMinsInput = "10"
    @State private var intervalCountInput = "2"
    @State private var countdownDurationInput = String(Int(defaultCountdownDuration))
    
    // Focused state to show step buttons
    @State private var focusedField: String? = nil
    
    // Audio Players
    @State private var startPlayer: AVAudioPlayer?
    @State private var bellPlayer: AVAudioPlayer?
    @State private var silentPlayer: AVAudioPlayer? // Looped silent audio to keep app executing in background
    
    // Background-safe dispatcher
    @StateObject private var bgTimer = BackgroundTimer()

    init() {
        let preferences = MeditationPreferences.load()
        _totalTime = State(initialValue: preferences.totalTime)
        _timeLeft = State(initialValue: preferences.totalTime)
        _intervalX = State(initialValue: preferences.intervalX)
        _intervalInputMode = State(initialValue: preferences.intervalInputMode)
        _intervalCount = State(initialValue: preferences.intervalCount)
        _isCountdownEnabled = State(initialValue: preferences.isCountdownEnabled)
        _countdownDuration = State(initialValue: preferences.countdownDuration)
        _countdownTimeLeft = State(initialValue: preferences.countdownDuration)
        _totalMinsInput = State(initialValue: String(Int(preferences.totalTime) / 60))
        _intervalMinsInput = State(initialValue: String(Int(preferences.intervalX) / 60))
        _intervalCountInput = State(initialValue: String(preferences.intervalCount))
        _countdownDurationInput = State(initialValue: String(Int(preferences.countdownDuration)))
    }
    
    var body: some View {
        ZStack {
            // 1. Immersive Buddha Background
            GeometryReader { geometry in
                homeBackgroundImageView
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .edgesIgnoringSafeArea(.all)
            
            // Warm Golden Overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 223.0 / 255.0, green: 172.0 / 255.0, blue: 54.0 / 255.0).opacity(0.38),
                    Color(red: 82.0 / 255.0, green: 69.0 / 255.0, blue: 39.0 / 255.0).opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            // 2. Main Content
            mainContentView
            
            // 3. Apple-Style Fixed Bottom Sheet settings panel
            if showSettings {
                ZStack(alignment: .bottom) {
                    // Soft dark touch-dismiss scrim
                    Color.black.opacity(0.25)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            dismissSettings()
                        }
                    
                    // Slide up native SwiftUI Options sheet
                    settingsSheetView
                        .transition(.move(edge: .bottom))
                }
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .preferredColorScheme(.light) // Force light color scheme (bronze/gold text) in Dark Mode
        .onAppear {
            loadAudioEngine()
            syncAllInputs()
            syncMeditationLiveActivityForCurrentSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            syncMeditationLiveActivityForCurrentSession()
        }
    }
    
    // MARK: - Subviews

    private var dhammaGold: Color {
        Color(red: 224.0 / 255.0, green: 174.0 / 255.0, blue: 64.0 / 255.0)
    }

    private var dhammaDeepGold: Color {
        Color(red: 197.0 / 255.0, green: 145.0 / 255.0, blue: 43.0 / 255.0)
    }

    private var dhammaSoftGold: Color {
        Color(red: 246.0 / 255.0, green: 217.0 / 255.0, blue: 151.0 / 255.0)
    }

    private var dhammaAntiqueGold: Color {
        Color(red: 176.0 / 255.0, green: 137.0 / 255.0, blue: 62.0 / 255.0)
    }

    private var dhammaInk: Color {
        Color(red: 44.0 / 255.0, green: 37.0 / 255.0, blue: 22.0 / 255.0)
    }

    private var dhammaPanel: Color {
        Color(red: 34.0 / 255.0, green: 31.0 / 255.0, blue: 21.0 / 255.0)
    }

    private var dhammaPanelStrong: Color {
        Color(red: 24.0 / 255.0, green: 23.0 / 255.0, blue: 17.0 / 255.0)
    }

    private var isSessionActive: Bool {
        isRunning || countdownActive || overtimeActive || timeLeft < totalTime
    }

    private var mainContentView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 312)

            timerCircleView

            sessionSummaryView
                .padding(.top, isSessionActive ? 14 : 0)

            if isSessionActive {
                Spacer()

                focusControlsGroupView
                    .padding(.horizontal, 34)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Spacer(minLength: 28)

                setupOptionsPanelView
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                setupStartButton
                    .padding(.top, 18)
                    .padding(.horizontal, 34)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: isSessionActive)
    }
    
    private var homeBackgroundImageView: Image {
        if let path = Bundle.main.path(forResource: "buddha-ios-home", ofType: "jpg", inDirectory: "public"),
           let uiImage = UIImage(contentsOfFile: path) {
            return Image(uiImage: uiImage)
        }
        return buddhaImageView
    }
    
    private var buddhaImageView: Image {
        if let path = Bundle.main.path(forResource: "buddha", ofType: "jpg", inDirectory: "public"),
           let uiImage = UIImage(contentsOfFile: path) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }
    
    private var timerCircleView: some View {
        ZStack {
            // Timer details
            VStack(spacing: isSessionActive ? 10 : 2) {
                if countdownActive || overtimeActive {
                    Text(overtimeActive ? "Extra time" : "Preparing")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(dhammaSoftGold)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 16)
                        .background(dhammaPanelStrong.opacity(0.58))
                        .clipShape(Capsule())
                }
                
                Text(timerDisplayText)
                    .font(.system(size: isSessionActive ? 74 : 72, weight: .light, design: .rounded))
                    .foregroundColor(dhammaSoftGold)
                    .shadow(color: Color.black.opacity(0.46), radius: isSessionActive ? 8 : 7, x: 0, y: 3)
                    .monospacedDigit()
            }
            .padding(.vertical, isSessionActive ? 18 : 12)
            .padding(.horizontal, isSessionActive ? 26 : 24)
            .frame(minWidth: isSessionActive ? 260 : 282)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(dhammaPanelStrong.opacity(isSessionActive ? 0.52 : 0.44))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(dhammaGold.opacity(isSessionActive ? 0.16 : 0.28), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isSessionActive ? 0.22 : 0.28), radius: 18, x: 0, y: 10)
        }
    }

    private var sessionSummaryView: some View {
        VStack(spacing: 8) {
            if let bellStatusText = sessionBellStatusText {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(bellStatusText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(dhammaSoftGold)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(dhammaPanelStrong.opacity(0.62))
                .clipShape(Capsule())
            }
        }
    }

    private var setupOptionsPanelView: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                HStack {
                    Text("Duration")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(dhammaSoftGold.opacity(0.9))
                    Spacer(minLength: 0)
                }

                Slider(value: Binding(get: { totalTime }, set: { val in
                    updateTotalTime(val)
                }), in: 60...maxMeditationTime, step: 60)
                .accentColor(dhammaGold)
            }

            Divider()
                .background(dhammaGold.opacity(0.24))

            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: effectiveIntervalCount > 1 ? "chart.bar.fill" : "bell.slash.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(dhammaGold)
                        .frame(width: 28, height: 28)
                        .background(dhammaGold.opacity(0.18))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(intervalInputMode == "count" ? "Interval bells" : "Bell interval")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(dhammaSoftGold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)
                        Text(intermediateBellSummaryText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(dhammaSoftGold.opacity(0.82))
                    }
                }

                Spacer()

                if intervalInputMode == "count" {
                    bellCountStepperView
                } else {
                    Image(systemName: "clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(dhammaGold)
                        .frame(width: 40, height: 32)
                        .background(dhammaGold.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(dhammaPanelStrong.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(dhammaGold.opacity(0.3), lineWidth: 1)
            )

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preparation")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(dhammaSoftGold)
                    Text(isCountdownEnabled ? "\(Int(countdownDuration)) seconds before start" : "Start immediately")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(dhammaSoftGold.opacity(0.78))
                }

                Spacer()

                Toggle("", isOn: Binding(get: { isCountdownEnabled }, set: { val in
                    isCountdownEnabled = val
                    if !countdownActive {
                        countdownTimeLeft = countdownDuration
                    }
                    savePreferences()
                }))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0)))
            }

            Button(action: {
                triggerHaptic()
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSettings = true
                }
            }) {
                Text("More settings")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(dhammaGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .padding(16)
        .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(dhammaPanel.opacity(0.68))
                .background(
                    VisualEffectBlur(blurStyle: .systemThinMaterialDark)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(dhammaGold.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.26), radius: 22, x: 0, y: 12)
    }

    private var setupStartButton: some View {
        Button(action: toggleTimer) {
            Text("Start")
                .font(.system(size: 23, weight: .bold))
                .foregroundColor(dhammaInk)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [dhammaGold, dhammaDeepGold]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(28)
                .shadow(color: Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.28), radius: 12, x: 0, y: 6)
        }
    }

    private var bellCountStepperView: some View {
        HStack(spacing: 9) {
            Button(action: {
                triggerHaptic()
                adjustValue(type: "intervalCount", up: false)
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(dhammaSoftGold)
                    .frame(width: 28, height: 28)
                    .background(dhammaPanelStrong.opacity(0.5))
                    .clipShape(Circle())
            }

            Text("\(effectiveIntervalCount)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(dhammaSoftGold)
                .frame(width: 28)
                .monospacedDigit()

            Button(action: {
                triggerHaptic()
                adjustValue(type: "intervalCount", up: true)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(dhammaSoftGold)
                    .frame(width: 28, height: 28)
                    .background(dhammaPanelStrong.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            Capsule()
                .fill(dhammaPanelStrong.opacity(0.46))
        )
        .overlay(
            Capsule()
                .stroke(dhammaGold.opacity(0.34), lineWidth: 1)
        )
    }

    private var focusControlsGroupView: some View {
        HStack(spacing: 16) {
            Button(action: toggleTimer) {
                Text(isRunning ? "Pause" : "Resume")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(dhammaInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(dhammaGold.opacity(0.92))
                    .cornerRadius(26)
            }

            Button(action: resetTimer) {
                Text("Stop")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(dhammaInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(red: 255.0 / 255.0, green: 250.0 / 255.0, blue: 240.0 / 255.0).opacity(0.86))
                    .cornerRadius(26)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.35), lineWidth: 1)
                    )
            }
        }
    }
    
    private var settingsSheetView: some View {
        VStack(spacing: 16) {
            // Drag handle indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(dhammaAntiqueGold.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
            
            Text("More Settings")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(dhammaAntiqueGold)
                .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            
            VStack(spacing: 20) {
                // Interval bell behavior
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interval bell")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(dhammaAntiqueGold)

                    HStack {
                        Text("Spacing")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(dhammaAntiqueGold)
                        
                        Spacer()
                        
                        CustomSegmentedPicker(
                            selection: Binding(get: { intervalInputMode }, set: { val in
                                triggerHaptic()
                                intervalInputMode = val
                                handleIntervalModeChange()
                            }),
                            options: [("By Count", "count"), ("By Time", "time")]
                        )
                    }
                    
                    if intervalInputMode == "time" {
                        HStack {
                            Text("Interval length")
                                .font(.system(size: 13))
                                .foregroundColor(dhammaAntiqueGold.opacity(0.9))
                            Spacer()
                            stepperTextField(value: $intervalMinsInput, suffix: "m", field: "intervalMins", increment: { adjustValue(type: "intervalMins", up: true) }, decrement: { adjustValue(type: "intervalMins", up: false) })
                        }
                        
                        Slider(value: Binding(get: { clampedMinuteInterval(intervalX) }, set: { val in
                            let rounded = clampedMinuteInterval(val)
                            intervalX = rounded
                            intervalCount = sectionCount(forTotal: totalTime, fixedInterval: rounded)
                            isCustomInterval = true
                            isRunning = false
                            timeLeft = totalTime
                            syncAllInputs()
                            savePreferences()
                        }), in: 60...max(60, totalTime), step: 60)
                        .accentColor(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0))
                    } else {
                        Text(hasIntermediateBells ? "Sections are adjusted on the main screen. Current spacing: \(formatIntervalLengthText(intermediateBellSpacing))" : "1 section means end bell only.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(dhammaAntiqueGold.opacity(0.78))
                    }
                }
                // Preparation length only; the on/off switch lives on the main screen.
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Preparation length")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(dhammaAntiqueGold)
                        
                        Spacer()
                        
                        stepperTextField(value: $countdownDurationInput, suffix: "s", field: "countdown", increment: { adjustValue(type: "countdown", up: true) }, decrement: { adjustValue(type: "countdown", up: false) })
                    }
                    
                    Slider(value: Binding(get: { countdownDuration }, set: { val in
                        countdownDuration = val
                        if !countdownActive {
                            countdownTimeLeft = val
                        }
                        syncAllInputs()
                        savePreferences()
                    }), in: 5...60, step: 1)
                    .accentColor(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0))
                }
            }
            .padding(.horizontal, 24)

            Text("Made by Luke for Dad, with Love ❤️😊")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(dhammaAntiqueGold.opacity(0.48))
                .padding(.top, 2)
                .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity)
        .background(
            Color(red: 255.0 / 255.0, green: 252.0 / 255.0, blue: 245.0 / 255.0)
                .opacity(0.9)
                .background(VisualEffectBlur(blurStyle: .systemMaterial))
        )
        .cornerRadius(24)
        .shadow(color: dhammaInk.opacity(0.16), radius: 32, x: 0, y: -8)
        .offset(y: settingsDragOffset)
        .gesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .updating($settingsDragOffset) { value, state, _ in
                    if value.translation.height > 0 {
                        state = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 70 || value.predictedEndTranslation.height > 140 {
                        triggerHaptic()
                        dismissSettings()
                    }
                }
        )
    }
    
    // Direct numerical steppers helper
    private func stepperTextField(value: Binding<String>, suffix: String, field: String, increment: @escaping () -> Void, decrement: @escaping () -> Void) -> some View {
        HStack(spacing: 2) {
            Button(action: {
                triggerHaptic()
                decrement()
            }) {
                Text("−")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 184.0 / 255.0, green: 134.0 / 255.0, blue: 11.0 / 255.0))
                    .frame(width: 18, height: 18)
                    .background(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.15))
                    .clipShape(Circle())
            }
            
            TextField("", text: value, onEditingChanged: { isEditing in
                if isEditing {
                    focusedField = field
                } else {
                    focusedField = nil
                    commitField(field)
                }
            })
            .keyboardType(.numberPad)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color(red: 184.0 / 255.0, green: 134.0 / 255.0, blue: 11.0 / 255.0))
            .frame(width: field == "intervalCount" ? 30 : 22, alignment: .trailing)
            .multilineTextAlignment(.trailing)
            
            Text(suffix)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(dhammaAntiqueGold)
            
            Button(action: {
                triggerHaptic()
                increment()
            }) {
                Text("+")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 184.0 / 255.0, green: 134.0 / 255.0, blue: 11.0 / 255.0))
                    .frame(width: 18, height: 18)
                    .background(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(red: 255.0 / 255.0, green: 250.0 / 255.0, blue: 240.0 / 255.0).opacity(0.6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(focusedField == field ? 0.8 : 0.4), lineWidth: 1)
        )
    }
    
    // MARK: - Logic & Actions
    
    private func formatIntervalLengthText(_ seconds: TimeInterval) -> String {
        let totalRounded = Int(round(seconds))
        let mins = totalRounded / 60
        let secs = totalRounded % 60
        return String(format: "%d:%02dm", mins, secs)
    }

    private func clampedMinuteInterval(_ seconds: TimeInterval, total: TimeInterval? = nil) -> TimeInterval {
        let limit = total ?? totalTime
        let minutes = max(1, Int(round(seconds / 60)))
        return min(limit, TimeInterval(minutes * 60))
    }

    private var effectiveIntervalCount: Int {
        if intervalInputMode == "time" {
            let interval = clampedMinuteInterval(intervalX)
            guard interval > 0 else { return 1 }
            return max(1, Int(round(totalTime / interval)))
        }
        return max(1, intervalCount)
    }

    private var maxIntervalSectionCount: Int {
        max(1, Int(totalTime / 5))
    }

    private func sectionCount(forTotal total: TimeInterval, fixedInterval: TimeInterval) -> Int {
        guard fixedInterval > 0 else { return 1 }
        return max(1, Int(round(total / fixedInterval)))
    }

    private var intermediateBellSpacing: TimeInterval {
        if intervalInputMode == "time" {
            return clampedMinuteInterval(intervalX)
        }
        return totalTime / Double(max(1, effectiveIntervalCount))
    }

    private var intermediateBellCount: Int {
        if intervalInputMode == "time" {
            let interval = clampedMinuteInterval(intervalX)
            guard interval > 0, interval < totalTime else { return 0 }
            return max(0, Int(floor((totalTime - 0.001) / interval)))
        }
        return max(0, effectiveIntervalCount - 1)
    }

    private var hasIntermediateBells: Bool {
        return intermediateBellCount > 0
    }

    private var intermediateBellSummaryText: String {
        guard hasIntermediateBells else {
            return "End bell only"
        }

        return "Bell every \(formatTime(intermediateBellSpacing))"
    }

    private var scheduledIntermediateBellSeconds: [Int] {
        guard hasIntermediateBells else { return [] }

        if intervalInputMode == "time" {
            let spacing = max(1, Int(round(intervalX)))
            let total = Int(round(totalTime))
            return Array(stride(from: spacing, to: total, by: spacing))
        }

        let count = effectiveIntervalCount
        guard count > 1 else { return [] }
        return (1..<count).map { index in
            Int(round(Double(index) * totalTime / Double(count)))
        }
    }

    private var nextIntermediateBellRemaining: TimeInterval? {
        let elapsed = max(0, totalTime - timeLeft)
        for bellSecond in scheduledIntermediateBellSeconds {
            let remaining = TimeInterval(bellSecond) - elapsed
            if remaining > 0.5 {
                return remaining
            }
        }
        return nil
    }

    private var nextOvertimeBellRemaining: TimeInterval? {
        guard hasIntermediateBells else { return nil }
        let spacing = max(1, Int(round(intermediateBellSpacing)))
        return TimerBellLogic.nextOvertimeBellRemaining(overtimeElapsed: overtimeElapsed, spacing: spacing)
    }

    private var sessionBellStatusText: String? {
        guard isSessionActive && !countdownActive && hasIntermediateBells else {
            return nil
        }

        if overtimeActive {
            guard let remaining = nextOvertimeBellRemaining else { return nil }
            return "Next bell in \(formatBellCountdownText(remaining))"
        }

        guard let remaining = nextIntermediateBellRemaining else { return nil }
        return "Next bell in \(formatBellCountdownText(remaining))"
    }

    private var liveActivityBellStatusText: String? {
        guard hasIntermediateBells else { return nil }
        return "Bell every \(TimerBellLogic.formatBellCadenceText(intermediateBellSpacing))"
    }

    private func formatBellCountdownText(_ seconds: TimeInterval) -> String {
        TimerBellLogic.formatBellCountdownText(seconds)
    }

    private var timerDisplayText: String {
        if overtimeActive {
            return TimerBellLogic.formatElapsedClockText(overtimeElapsed)
        }

        return TimerBellLogic.formatCountdownClockText(countdownActive ? countdownTimeLeft : timeLeft)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalRounded = Int(round(seconds))
        let mins = totalRounded / 60
        let secs = totalRounded % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func stopAllGongs() {
        if let player = startPlayer, player.isPlaying {
            player.stop()
        }
        if let player = bellPlayer, player.isPlaying {
            player.stop()
        }
    }

    private func savePreferences() {
        MeditationPreferences(
            totalTime: totalTime,
            intervalInputMode: intervalInputMode,
            intervalCount: intervalCount,
            intervalX: intervalX,
            isCountdownEnabled: isCountdownEnabled,
            countdownDuration: countdownDuration
        ).save()
    }

    private func updateTotalTime(_ value: TimeInterval) {
        let capped = min(maxMeditationTime, max(60, value))
        totalTime = capped
        timeLeft = capped
        isRunning = false
        countdownActive = false
        sessionStartTime = nil
        accumulatedElapsed = 0
        lastProcessedSecond = 0
        overtimeActive = false
        overtimeStartTime = nil
        overtimeAccumulated = 0
        overtimeElapsed = 0

        if intervalInputMode == "count" {
            intervalCount = min(max(1, intervalCount), maxIntervalSectionCount)
            intervalX = capped / Double(intervalCount)
        } else {
            intervalX = clampedMinuteInterval(intervalX, total: capped)
            intervalCount = sectionCount(forTotal: capped, fixedInterval: intervalX)
        }

        silentPlayer?.stop()
        bgTimer.stop()
        endMeditationLiveActivity()
        syncAllInputs()
        savePreferences()
    }
    
    private func toggleTimer() {
        triggerHaptic()
        if !isRunning {
            hideKeyboard()
            showSettings = false
            if overtimeActive {
                overtimeStartTime = Date()
                resumeOvertimeLiveActivity(elapsed: overtimeElapsed)
            } else if timeLeft == totalTime && !countdownActive {
                if isCountdownEnabled {
                    countdownActive = true
                    countdownTimeLeft = countdownDuration
                } else {
                    playGong()
                    startMeditationLiveActivity(remaining: timeLeft)
                }
                sessionStartTime = Date()
            } else {
                sessionStartTime = Date()
                if !countdownActive && !overtimeActive {
                    resumeMeditationLiveActivity(remaining: timeLeft)
                }
            }
            isRunning = true
            
            // Loop silent player on repeat to keep background audio thread alive
            silentPlayer?.currentTime = 0
            silentPlayer?.play()
            
            // Start queue-driven background timer
            bgTimer.onTick = {
                timerTick()
            }
            bgTimer.start()
        } else {
            if overtimeActive, let start = overtimeStartTime {
                overtimeAccumulated += Date().timeIntervalSince(start)
                overtimeElapsed = overtimeAccumulated
                pauseMeditationLiveActivity(remaining: 0, overtimeElapsed: overtimeElapsed)
            } else if let start = sessionStartTime {
                accumulatedElapsed += Date().timeIntervalSince(start)
                if !countdownActive {
                    timeLeft = max(0, totalTime - accumulatedElapsed)
                    pauseMeditationLiveActivity(remaining: timeLeft, overtimeElapsed: nil)
                }
            }
            sessionStartTime = nil
            overtimeStartTime = nil
            isRunning = false
            stopAllGongs()
            
            // Stop background timers
            silentPlayer?.stop()
            bgTimer.stop()
        }
    }
    
    private func resetTimer() {
        triggerHaptic()
        hideKeyboard()
        showSettings = false
        isRunning = false
        countdownActive = false
        sessionStartTime = nil
        overtimeStartTime = nil
        accumulatedElapsed = 0
        lastProcessedSecond = 0
        overtimeActive = false
        overtimeAccumulated = 0
        overtimeElapsed = 0
        timeLeft = totalTime
        stopAllGongs()
        
        // Stop background timers
        silentPlayer?.stop()
        bgTimer.stop()
        endMeditationLiveActivity()
    }
    
    private func timerTick() {
        guard isRunning else { return }
        
        if countdownActive {
            if countdownTimeLeft <= 1 {
                countdownActive = false
                playGong()
                sessionStartTime = Date()
                accumulatedElapsed = 0
                lastProcessedSecond = 0
                startMeditationLiveActivity(remaining: totalTime)
            } else {
                countdownTimeLeft -= 1
            }
        } else {
            if overtimeActive {
                if let start = overtimeStartTime {
                    overtimeElapsed = overtimeAccumulated + Date().timeIntervalSince(start)
                }
                liveActivityLog.info("Timer tick overtime active elapsed=\(self.overtimeElapsed, privacy: .public) accumulated=\(self.overtimeAccumulated, privacy: .public)")
                appendLiveActivityDebugLog("Timer tick overtime active elapsed=\(overtimeElapsed) accumulated=\(overtimeAccumulated)")
                playOvertimeIntermediateBellIfNeeded(currentSecond: TimerBellLogic.elapsedSecondForBellProcessing(overtimeElapsed))
                timeLeft = 0
                return
            }

            guard let start = sessionStartTime else { return }
            let totalElapsed = accumulatedElapsed + Date().timeIntervalSince(start)
            let transition = TimerBellLogic.runningSessionTransition(totalDuration: totalTime, elapsed: totalElapsed)
            timeLeft = transition.remaining

            if let overtimeElapsedAtEnd = transition.overtimeElapsed {
                liveActivityLog.info("Timer reached end totalElapsed=\(totalElapsed, privacy: .public) totalTime=\(self.totalTime, privacy: .public) overtimeElapsed=\(overtimeElapsedAtEnd, privacy: .public)")
                appendLiveActivityDebugLog("Timer reached end totalElapsed=\(totalElapsed) totalTime=\(totalTime) overtimeElapsed=\(overtimeElapsedAtEnd)")
                overtimeActive = true
                overtimeStartTime = Date().addingTimeInterval(-overtimeElapsedAtEnd)
                overtimeAccumulated = 0
                overtimeElapsed = overtimeElapsedAtEnd
                timeLeft = 0
                sessionStartTime = nil
                accumulatedElapsed = 0
                lastProcessedSecond = TimerBellLogic.elapsedSecondForBellProcessing(overtimeElapsedAtEnd)
                startOvertimeLiveActivity(elapsed: overtimeElapsed)
                liveActivityLog.info("Timer scheduled overtime Live Activity update before end gong")
                appendLiveActivityDebugLog("Timer scheduled overtime Live Activity update before end gong")
                playEndGong()
                return
            }
            
            let currentSecond = Int(totalElapsed)
            if currentSecond > lastProcessedSecond {
                let scheduledBells = Set(scheduledIntermediateBellSeconds)
                for sec in (lastProcessedSecond + 1)...currentSecond {
                    if scheduledBells.contains(sec) {
                        playIntervalGong()
                    }
                }
                lastProcessedSecond = currentSecond
            }
        }
    }

    private func playOvertimeIntermediateBellIfNeeded(currentSecond: Int) {
        guard hasIntermediateBells, currentSecond > lastProcessedSecond else { return }

        let spacing = max(1, Int(round(intermediateBellSpacing)))
        for sec in (lastProcessedSecond + 1)...currentSecond {
            if sec > 0 && sec % spacing == 0 {
                playIntervalGong()
            }
        }
        lastProcessedSecond = currentSecond
    }

    private func startMeditationLiveActivity(remaining: TimeInterval) {
        if #available(iOS 16.1, *) {
            liveActivityLog.info("App start Live Activity countdown remaining=\(remaining, privacy: .public) bellStatus=\(self.liveActivityBellStatusText ?? "nil", privacy: .public)")
            appendLiveActivityDebugLog("App start Live Activity countdown remaining=\(remaining) bellStatus=\(liveActivityBellStatusText ?? "nil")")
            MeditationLiveActivityController.shared.start(
                totalDuration: totalTime,
                remaining: remaining,
                bellStatusText: liveActivityBellStatusText
            )
        }
    }

    private func resumeMeditationLiveActivity(remaining: TimeInterval) {
        if #available(iOS 16.1, *) {
            liveActivityLog.info("App sync Live Activity countdown remaining=\(remaining, privacy: .public) bellStatus=\(self.liveActivityBellStatusText ?? "nil", privacy: .public)")
            appendLiveActivityDebugLog("App sync Live Activity countdown remaining=\(remaining) bellStatus=\(liveActivityBellStatusText ?? "nil")")
            MeditationLiveActivityController.shared.syncRunning(
                totalDuration: totalTime,
                remaining: remaining,
                bellStatusText: liveActivityBellStatusText
            )
        }
    }

    private func updateRunningLiveActivity(remaining: TimeInterval) {
        if #available(iOS 16.1, *) {
            liveActivityLog.info("App update Live Activity running remaining=\(remaining, privacy: .public) bellStatus=\(self.liveActivityBellStatusText ?? "nil", privacy: .public)")
            appendLiveActivityDebugLog("App update Live Activity running remaining=\(remaining) bellStatus=\(liveActivityBellStatusText ?? "nil")")
            MeditationLiveActivityController.shared.updateRunning(
                remaining: remaining,
                bellStatusText: liveActivityBellStatusText
            )
        }
    }

    private func startOvertimeLiveActivity(elapsed: TimeInterval) {
        if #available(iOS 16.1, *) {
            liveActivityLog.info("App start Live Activity overtime elapsed=\(elapsed, privacy: .public) bellStatus=\(self.liveActivityBellStatusText ?? "nil", privacy: .public)")
            appendLiveActivityDebugLog("App start Live Activity overtime elapsed=\(elapsed) bellStatus=\(liveActivityBellStatusText ?? "nil")")
            MeditationLiveActivityController.shared.startOvertime(
                totalDuration: totalTime,
                overtimeElapsed: elapsed,
                bellStatusText: liveActivityBellStatusText
            )
        }
    }

    private func resumeOvertimeLiveActivity(elapsed: TimeInterval) {
        if #available(iOS 16.1, *) {
            liveActivityLog.info("App sync Live Activity overtime elapsed=\(elapsed, privacy: .public) bellStatus=\(self.liveActivityBellStatusText ?? "nil", privacy: .public)")
            appendLiveActivityDebugLog("App sync Live Activity overtime elapsed=\(elapsed) bellStatus=\(liveActivityBellStatusText ?? "nil")")
            MeditationLiveActivityController.shared.syncOvertime(
                totalDuration: totalTime,
                overtimeElapsed: elapsed,
                bellStatusText: liveActivityBellStatusText
            )
        }
    }

    private func updateOvertimeLiveActivity(elapsed: TimeInterval) {
        if #available(iOS 16.1, *) {
            liveActivityLog.info("App update Live Activity overtime elapsed=\(elapsed, privacy: .public) bellStatus=\(self.liveActivityBellStatusText ?? "nil", privacy: .public)")
            appendLiveActivityDebugLog("App update Live Activity overtime elapsed=\(elapsed) bellStatus=\(liveActivityBellStatusText ?? "nil")")
            MeditationLiveActivityController.shared.updateOvertime(
                overtimeElapsed: elapsed,
                bellStatusText: liveActivityBellStatusText
            )
        }
    }

    private func pauseMeditationLiveActivity(remaining: TimeInterval, overtimeElapsed: TimeInterval?) {
        if #available(iOS 16.1, *) {
            liveActivityLog.info("App pause Live Activity remaining=\(remaining, privacy: .public) overtimeElapsed=\(overtimeElapsed ?? -1, privacy: .public) bellStatus=\(self.liveActivityBellStatusText ?? "nil", privacy: .public)")
            appendLiveActivityDebugLog("App pause Live Activity remaining=\(remaining) overtimeElapsed=\(overtimeElapsed ?? -1) bellStatus=\(liveActivityBellStatusText ?? "nil")")
            MeditationLiveActivityController.shared.syncPaused(
                totalDuration: totalTime,
                remaining: remaining,
                overtimeElapsed: overtimeElapsed,
                bellStatusText: liveActivityBellStatusText
            )
        }
    }

    private func syncMeditationLiveActivityForCurrentSession() {
        liveActivityLog.info("App foreground sync requested isSessionActive=\(self.isSessionActive, privacy: .public) countdownActive=\(self.countdownActive, privacy: .public) isRunning=\(self.isRunning, privacy: .public) overtimeActive=\(self.overtimeActive, privacy: .public) timeLeft=\(self.timeLeft, privacy: .public) overtimeElapsed=\(self.overtimeElapsed, privacy: .public)")
        appendLiveActivityDebugLog("App foreground sync requested isSessionActive=\(isSessionActive) countdownActive=\(countdownActive) isRunning=\(isRunning) overtimeActive=\(overtimeActive) timeLeft=\(timeLeft) overtimeElapsed=\(overtimeElapsed)")
        guard MeditationLiveActivityLogic.shouldSyncOnForeground(isSessionActive: isSessionActive, countdownActive: countdownActive) else {
            liveActivityLog.info("App foreground sync skipped")
            appendLiveActivityDebugLog("App foreground sync skipped")
            return
        }

        if overtimeActive {
            if isRunning {
                syncOvertimeLiveActivity(elapsed: overtimeElapsed)
            } else {
                pauseMeditationLiveActivity(remaining: 0, overtimeElapsed: overtimeElapsed)
            }
            return
        }

        if isRunning {
            resumeMeditationLiveActivity(remaining: timeLeft)
        } else {
            pauseMeditationLiveActivity(remaining: timeLeft, overtimeElapsed: nil)
        }
    }

    private func syncOvertimeLiveActivity(elapsed: TimeInterval) {
        if #available(iOS 16.1, *) {
            MeditationLiveActivityController.shared.syncOvertime(
                totalDuration: totalTime,
                overtimeElapsed: elapsed,
                bellStatusText: liveActivityBellStatusText
            )
        }
    }

    private func endMeditationLiveActivity() {
        if #available(iOS 16.1, *) {
            liveActivityLog.info("App end Live Activity requested")
            appendLiveActivityDebugLog("App end Live Activity requested")
            MeditationLiveActivityController.shared.end()
        }
    }

    // Direct inputs committing
    private func commitField(_ field: String) {
        switch field {
        case "totalMins":
            let mins = Int(totalMinsInput) ?? 0
            let newTotal = TimeInterval(mins * 60)
            if newTotal >= 60 {
                let capped = min(maxMeditationTime, newTotal)
                totalTime = capped
                timeLeft = capped
                isRunning = false
                
                if intervalInputMode == "count" {
                    intervalCount = min(max(1, intervalCount), maxIntervalSectionCount)
                    intervalX = capped / Double(intervalCount)
                } else {
                    intervalX = clampedMinuteInterval(intervalX, total: capped)
                    intervalCount = sectionCount(forTotal: capped, fixedInterval: intervalX)
                }
            }
            syncAllInputs()
            
        case "intervalMins":
            let mins = max(1, Int(intervalMinsInput) ?? 1)
            let newInterval = TimeInterval(mins * 60)
            if newInterval <= totalTime {
                intervalX = newInterval
                intervalCount = sectionCount(forTotal: totalTime, fixedInterval: newInterval)
                isCustomInterval = true
                isRunning = false
                timeLeft = totalTime
            }
            syncAllInputs()
            
        case "intervalCount":
            let count = min(max(1, Int(intervalCountInput) ?? 2), maxIntervalSectionCount)
            if count >= 1 {
                let calculated = totalTime / Double(count)
                intervalX = max(5, min(totalTime, calculated))
                intervalCount = count
                isCustomInterval = true
                isRunning = false
                timeLeft = totalTime
            }
            syncAllInputs()
            
        case "countdown":
            let val = Int(countdownDurationInput) ?? Int(defaultCountdownDuration)
            countdownDuration = max(3, min(maxCountdownDuration, TimeInterval(val)))
            if !countdownActive {
                countdownTimeLeft = countdownDuration
            }
            syncAllInputs()
            
        default:
            break
        }
        savePreferences()
    }
    
    private func adjustValue(type: String, up: Bool) {
        switch type {
        case "totalMins":
            let current = Int(totalMinsInput) ?? 0
            totalMinsInput = String(max(1, current + (up ? 1 : -1)))
            commitField("totalMins")
        case "intervalMins":
            let current = Int(intervalMinsInput) ?? 0
            let maxMinutes = max(1, Int(totalTime / 60))
            intervalMinsInput = String(min(maxMinutes, max(1, current + (up ? 1 : -1))))
            commitField("intervalMins")
        case "intervalCount":
            let current = intervalCount
            intervalCountInput = String(min(maxIntervalSectionCount, max(1, current + (up ? 1 : -1))))
            commitField("intervalCount")
        case "countdown":
            let current = Int(countdownDurationInput) ?? Int(defaultCountdownDuration)
            countdownDurationInput = String(max(3, current + (up ? 1 : -1)))
            commitField("countdown")
        default:
            break
        }
    }
    
    private func handleIntervalModeChange() {
        if intervalInputMode == "time" {
            let rounded = clampedMinuteInterval(intervalX)
            intervalX = rounded
            intervalCount = sectionCount(forTotal: totalTime, fixedInterval: rounded)
            isCustomInterval = true
        } else {
            let count = min(max(1, intervalCount), maxIntervalSectionCount)
            if count >= 1 {
                intervalCount = count
                let calculated = totalTime / Double(count)
                intervalX = calculated
                if count == 2 || round(calculated) == round(totalTime / 2) {
                    isCustomInterval = false
                }
            }
        }
        syncAllInputs()
        savePreferences()
    }
    
    private func syncAllInputs() {
        // sync total time inputs
        let tm = Int(totalTime) / 60
        totalMinsInput = String(tm)
        
        // sync interval time inputs
        let im = Int(clampedMinuteInterval(intervalX)) / 60
        intervalMinsInput = String(im)
        
        // sync count input
        let fixedInterval = clampedMinuteInterval(intervalX)
        let count = intervalInputMode == "count" ? min(intervalCount, maxIntervalSectionCount) : (fixedInterval > 0 ? Int(round(totalTime / fixedInterval)) : 2)
        intervalCountInput = String(count)
        
        // sync countdown
        countdownDurationInput = String(Int(countdownDuration))
    }
    
    // MARK: - Audio Engine Helpers
    
    private func loadAudioEngine() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to initialize AVAudioSession: \(error)")
        }
        
        if let startPath = Bundle.main.path(forResource: "start", ofType: "mp3", inDirectory: "audio") {
            let url = URL(fileURLWithPath: startPath)
            startPlayer = try? AVAudioPlayer(contentsOf: url)
            startPlayer?.prepareToPlay()
        }
        
        if let bellPath = Bundle.main.path(forResource: "interval-bell", ofType: "mp3", inDirectory: "audio") {
            let url = URL(fileURLWithPath: bellPath)
            bellPlayer = try? AVAudioPlayer(contentsOf: url)
            bellPlayer?.prepareToPlay()
            
            // Set up inaudible silent background looper
            silentPlayer = try? AVAudioPlayer(contentsOf: url)
            silentPlayer?.numberOfLoops = -1 // Repeat infinitely
            silentPlayer?.volume = 0.0 // Completely silent
            silentPlayer?.prepareToPlay()
        }
    }
    
    private func playGong() {
        triggerHaptic()
        if let player = startPlayer {
            player.rate = 1.0
            player.volume = 0.0
            player.enableRate = true
            player.currentTime = 0
            player.play()
            player.setVolume(startGongVolume, fadeDuration: 0.04)
        }
    }
    
    private func playIntervalGong() {
        triggerHaptic()
        if let player = bellPlayer {
            player.rate = 1.0
            player.volume = 0.0
            player.enableRate = true
            player.currentTime = 0
            player.play()
            player.setVolume(intervalGongVolume, fadeDuration: 0.04)
        }
    }
    
    private func playEndGong() {
        playGong()
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func dismissSettings() {
        withAnimation(.easeInOut(duration: 0.3)) {
            hideKeyboard()
            showSettings = false
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Visual Effect Blur helper for premium glassmorphism sheet background
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// Custom premium Segmented Control representing elegant capsules, golden gradients, and spring animations
struct CustomSegmentedPicker: View {
    @Binding var selection: String
    var options: [(String, String)] // Array of (displayName, tagValue)
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.1) { option in
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        selection = option.1
                    }
                }) {
                    Text(option.0)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(selection == option.1 ? Color(red: 44.0 / 255.0, green: 37.0 / 255.0, blue: 22.0 / 255.0) : Color(red: 176.0 / 255.0, green: 137.0 / 255.0, blue: 62.0 / 255.0))
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 62)
                        .background(
                            ZStack {
                                if selection == option.1 {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 224.0 / 255.0, green: 174.0 / 255.0, blue: 64.0 / 255.0),
                                                    Color(red: 197.0 / 255.0, green: 145.0 / 255.0, blue: 43.0 / 255.0)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.35), radius: 3, x: 0, y: 1.5)
                                }
                            }
                        )
                }
            }
        }
        .padding(2)
        .background(Color(red: 255.0 / 255.0, green: 250.0 / 255.0, blue: 240.0 / 255.0).opacity(0.55))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.35), lineWidth: 1)
        )
    }
}
