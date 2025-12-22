//
//  MuhaffezView.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import SwiftUI

struct MuhaffezView: View {
    @StateObject var recognizer = ArabicSpeechRecognizer()
    @State var viewModel = MuhaffezViewModel()
    @AppStorage("hasSeenTooltip") private var hasSeenTooltip = false
    @AppStorage("hasSeenStopTooltip") private var hasSeenStopTooltip = false
    @AppStorage("hasSeenRestartTooltip") private var hasSeenRestartTooltip = false
    @State private var showStopTooltip = false
    @State private var showRestartTooltip = false
    @State private var silenceTimer: Timer?

    var body: some View {
        VStack {
            if viewModel.matchedWords.count == 0 && !viewModel.textToPredict.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(2)
                    Spacer()
                }
                Spacer()
            } else {
                TwoPagesView(viewModel: viewModel)
            }
            if !hasSeenTooltip {
                tooltipView(text: String(localized: "Tap here and start reciting from the Quran"), color: .blue)
            }
            if showStopTooltip && !hasSeenStopTooltip {
                tooltipView(text: String(localized: "Tap here to stop recording, then you can start a new recitation"), color: .orange)
            }
            if showRestartTooltip && !hasSeenRestartTooltip {
                tooltipView(text: String(localized: "Tap here to start a new recitation"), color: .green)
            }
            Button(action: {
                hasSeenTooltip = true
                if viewModel.isRecording {
                    hasSeenStopTooltip = true
                    showStopTooltip = false
                    silenceTimer?.invalidate()
                    silenceTimer = nil
                    UIApplication.shared.isIdleTimerDisabled = false
                    recognizer.stopRecording()
                    // Show restart tooltip after stopping
                    if !hasSeenRestartTooltip {
                        showRestartTooltip = true
                    }
                } else {
                    if showRestartTooltip {
                        hasSeenRestartTooltip = true
                    }
                    showRestartTooltip = false
                    UIApplication.shared.isIdleTimerDisabled = true
                    viewModel.resetData()
                    Task {
                        try? recognizer.startRecording()
                    }
                }
                viewModel.isRecording.toggle()
            }) {
                Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.isRecording ? .red : .blue)
                    .padding()
                    .background(Circle().fill(Color(.systemGray6)))
                    .shadow(radius: 4)
            }
        }
        .onChange(of: recognizer.voiceText) { _, newValue in
            viewModel.voiceText = newValue

            // Reset and start silence timer when user starts recording and has text
            if viewModel.isRecording && !newValue.isEmpty && !hasSeenStopTooltip {
                showStopTooltipTimer()
            }
        }
        .onChange(of: viewModel.isRecording) { _, isRecording in
            if !isRecording {
                silenceTimer?.invalidate()
                silenceTimer = nil
                showStopTooltip = false
            }
        }
        .onAppear {
            // Use this for testing rub3 mark before
            //      viewModel.voiceText = "ذٰلِكَ بِأَنَّ اللَّهَ نَزَّلَ الكِتابَ بِالحَقِّ وَإِنَّ الَّذينَ اختَلَفوا فِي الكِتابِ لَفي شِقاقٍ بَعيدٍ"
            
            // Use this for testing rub3 mark and after
            //viewModel.voiceText = "لَيسَ البِرَّ أَن تُوَلّوا وُجوهَكُم قِبَلَ المَشرِقِ وَالمَغرِبِ"
            
            // Use this for testing changing page content
            //      viewModel.voiceText = "إِنَّ الَّذينَ كَفَروا سَواءٌ عَلَيهِم أَأَنذَرتَهُم أَم لَم تُنذِرهُم لا يُؤمِنونَ"
            //      Task {
            //        try? await Task.sleep(for: .seconds(2))
            //        viewModel.voiceText = """
            //                  إِنَّ الَّذينَ كَفَروا سَواءٌ عَلَيهِم أَأَنذَرتَهُم أَم لَم تُنذِرهُم لا يُؤمِنونَ
            //                  خَتَمَ اللَّهُ عَلىٰ قُلوبِهِم وَعَلىٰ سَمعِهِم وَعَلىٰ أَبصارِهِم غِشاوَةٌ وَلَهُم عَذابٌ عَظيمٌ
            //                  وَمِنَ النّاسِ مَن يَقولُ آمَنّا بِاللَّهِ وَبِاليَومِ الآخِرِ وَما هُم بِمُؤمِنينَ
            //                  يُخادِعونَ اللَّهَ وَالَّذينَ آمَنوا وَما يَخدَعونَ إِلّا أَنفُسَهُم وَما يَشعُرونَ
            //                  في قُلوبِهِم مَرَضٌ فَزادَهُمُ اللَّهُ مَرَضًا وَلَهُم عَذابٌ أَليمٌ بِما كانوا يَكذِبونَ
            //                  وَإِذا قيلَ لَهُم لا تُفسِدوا فِي الأَرضِ قالوا إِنَّما نَحنُ مُصلِحونَ
            //                  أَلا إِنَّهُم هُمُ المُفسِدونَ وَلٰكِن لا يَشعُرونَ
            //                  وَإِذا قيلَ لَهُم آمِنوا كَما آمَنَ النّاسُ قالوا أَنُؤمِنُ كَما آمَنَ السُّفَهاءُ أَلا إِنَّهُم هُمُ السُّفَهاءُ وَلٰكِن لا يَعلَمونَ
            //                  وَإِذا لَقُوا الَّذينَ آمَنوا قالوا آمَنّا وَإِذا خَلَوا إِلىٰ شَياطينِهِم قالوا إِنّا مَعَكُم إِنَّما نَحنُ مُستَهزِئونَ
            //                  اللَّهُ يَستَهزِئُ بِهِم وَيَمُدُّهُم في طُغيانِهِم يَعمَهونَ
            //                  أُولٰئِكَ الَّذينَ اشتَرَوُا الضَّلالَةَ بِالهُدىٰ فَما رَبِحَت تِجارَتُهُم وَما كانوا مُهتَدينَ
            //                  """
            //      }
            
            // Use for testing displaying surah Alfateha
            //      viewModel.voiceText = "الحَمدُ لِلَّهِ رَبِّ العالَمينَ"
            //      Task {
            //        try? await Task.sleep(for: .seconds(0.2))
            //        viewModel.voiceText = """
            //          الحَمدُ لِلَّهِ رَبِّ العالَمينَ
            //          الرَّحمٰنِ الرَّحيمِ
            //          مالِكِ يَومِ الدّينِ
            //          إِيّاكَ نَعبُدُ وَإِيّاكَ نَستَعينُ
            //          اهدِنَا الصِّراطَ المُستَقيمَ
            //          صِراطَ الَّذينَ أَنعَمتَ عَلَيهِم غَيرِ المَغضوبِ عَلَيهِم وَلَا الضّالّينَ
            //
            //          -
            //          الم ذٰلِكَ الكِتابُ لا رَيبَ فيهِ هُدًى لِلمُتَّقينَ
            //          """
            //      }
            
            // Use this testing to test long page
            //      viewModel.voiceText = "لا يَستَوِي القاعِدونَ مِنَ المُؤمِنينَ غَيرُ أُولِي الضَّرَرِ وَالمُجاهِدونَ في سَبيلِ اللَّهِ بِأَموالِهِم وَأَنفُسِهِم فَضَّلَ اللَّهُ"
            //      Task {
            //        try? await Task.sleep(for: .seconds(0.2))
            //        viewModel.voiceText = """
            //            لا يَستَوِي القاعِدونَ مِنَ المُؤمِنينَ غَيرُ أُولِي الضَّرَرِ وَالمُجاهِدونَ في سَبيلِ اللَّهِ بِأَموالِهِم وَأَنفُسِهِم فَضَّلَ اللَّهُ المُجاهِدينَ بِأَموالِهِم وَأَنفُسِهِم عَلَى القاعِدينَ دَرَجَةً وَكُلًّا وَعَدَ اللَّهُ الحُسنىٰ وَفَضَّلَ اللَّهُ المُجاهِدينَ عَلَى القاعِدينَ أَجرًا عَظيمًا
            //            دَرَجاتٍ مِنهُ وَمَغفِرَةً وَرَحمَةً وَكانَ اللَّهُ غَفورًا رَحيمًا
            //            إِنَّ الَّذينَ تَوَفّاهُمُ المَلائِكَةُ ظالِمي أَنفُسِهِم قالوا فيمَ كُنتُم قالوا كُنّا مُستَضعَفينَ فِي الأَرضِ قالوا أَلَم تَكُن أَرضُ اللَّهِ واسِعَةً فَتُهاجِروا فيها فَأُولٰئِكَ مَأواهُم جَهَنَّمُ وَساءَت مَصيرًا
            //            إِلَّا المُستَضعَفينَ مِنَ الرِّجالِ وَالنِّساءِ وَالوِلدانِ لا يَستَطيعونَ حيلَةً وَلا يَهتَدونَ سَبيلًا
            //            فَأُولٰئِكَ عَسَى اللَّهُ أَن يَعفُوَ عَنهُم وَكانَ اللَّهُ عَفُوًّا غَفورًا
            //            وَمَن يُهاجِر في سَبيلِ اللَّهِ يَجِد فِي الأَرضِ مُراغَمًا كَثيرًا وَسَعَةً وَمَن يَخرُج مِن بَيتِهِ مُهاجِرًا إِلَى اللَّهِ وَرَسولِهِ ثُمَّ يُدرِكهُ المَوتُ فَقَد وَقَعَ أَجرُهُ عَلَى اللَّهِ وَكانَ اللَّهُ غَفورًا رَحيمًا
            //            وَإِذا ضَرَبتُم فِي الأَرضِ فَلَيسَ عَلَيكُم جُناحٌ أَن تَقصُروا مِنَ الصَّلاةِ إِن خِفتُم أَن يَفتِنَكُمُ الَّذينَ كَفَروا إِنَّ الكافِرينَ كانوا لَكُم عَدُوًّا مُبينًا
            //            """
            //      }
            
            // Use this testing to test longer page of last page of Kahf
            //      viewModel.voiceText = "قالَ هٰذا رَحمَةٌ مِن رَبّي فَإِذا جاءَ وَعدُ رَبّي جَعَلَهُ دَكّاءَ وَكانَ وَعدُ رَبّي حَقًّا"
            //      Task {
            //        try? await Task.sleep(for: .seconds(0.2))
            //        viewModel.voiceText = """
            //          قالَ هٰذا رَحمَةٌ مِن رَبّي فَإِذا جاءَ وَعدُ رَبّي جَعَلَهُ دَكّاءَ وَكانَ وَعدُ رَبّي حَقًّا
            //          وَتَرَكنا بَعضَهُم يَومَئِذٍ يَموجُ في بَعضٍ وَنُفِخَ فِي الصّورِ فَجَمَعناهُم جَمعًا
            //          وَعَرَضنا جَهَنَّمَ يَومَئِذٍ لِلكافِرينَ عَرضًا
            //          الَّذينَ كانَت أَعيُنُهُم في غِطاءٍ عَن ذِكري وَكانوا لا يَستَطيعونَ سَمعًا
            //          أَفَحَسِبَ الَّذينَ كَفَروا أَن يَتَّخِذوا عِبادي مِن دوني أَولِياءَ إِنّا أَعتَدنا جَهَنَّمَ لِلكافِرينَ نُزُلًا
            //          قُل هَل نُنَبِّئُكُم بِالأَخسَرينَ أَعمالًا
            //          الَّذينَ ضَلَّ سَعيُهُم فِي الحَياةِ الدُّنيا وَهُم يَحسَبونَ أَنَّهُم يُحسِنونَ صُنعًا
            //          أُولٰئِكَ الَّذينَ كَفَروا بِآياتِ رَبِّهِم وَلِقائِهِ فَحَبِطَت أَعمالُهُم فَلا نُقيمُ لَهُم يَومَ القِيامَةِ وَزنًا
            //          ذٰلِكَ جَزاؤُهُم جَهَنَّمُ بِما كَفَروا وَاتَّخَذوا آياتي وَرُسُلي هُزُوًا
            //          إِنَّ الَّذينَ آمَنوا وَعَمِلُوا الصّالِحاتِ كانَت لَهُم جَنّاتُ الفِردَوسِ نُزُلًا
            //          خالِدينَ فيها لا يَبغونَ عَنها حِوَلًا
            //          قُل لَو كانَ البَحرُ مِدادًا لِكَلِماتِ رَبّي لَنَفِدَ البَحرُ قَبلَ أَن تَنفَدَ كَلِماتُ رَبّي وَلَو جِئنا بِمِثلِهِ مَدَدًا
            //          قُل إِنَّما أَنا بَشَرٌ مِثلُكُم يوحىٰ إِلَيَّ أَنَّما إِلٰهُكُم إِلٰهٌ واحِدٌ فَمَن كانَ يَرجو لِقاءَ رَبِّهِ فَليَعمَل عَمَلًا صالِحًا وَلا يُشرِك بِعِبادَةِ رَبِّهِ أَحَدًا
            //          """
            //      }

        }
    }

    private func tooltipView(text: String, color: Color, showArrow: Bool = true) -> some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color)
                )
                .shadow(radius: 8)
            if showArrow {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 25))
                    .foregroundColor(color)
            }
        }
    }

    func showStopTooltipTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            showStopTooltip = true
        }
    }
}

#Preview {
  MuhaffezView()
}
