//
//  TwoPagesView.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/24/25.
//

import SwiftUI

struct TwoPagesView: View {
  @Bindable var viewModel: MuhaffezViewModel
  @State private var scrollToPage: String? = nil

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 0) {
          pageView(pageModel: viewModel.leftPage, isRight: false)
            .padding(.leading, 4)
            .frame(width: UIScreen.main.bounds.width)
            .id("LEFT")
          pageView(pageModel: viewModel.rightPage, isRight: true)
            .padding(.trailing, 4)
            .frame(width: UIScreen.main.bounds.width)
            .id("RIGHT")
        }
      }
      .onChange(of: viewModel.rightPage.text) {
        scrollToCurrentPage(using: proxy)
      }
      .onChange(of: viewModel.leftPage.text) {
        scrollToCurrentPage(using: proxy)
      }
      .onAppear {
        proxy.scrollTo("RIGHT", anchor: .center)

        // Use this for testing moving to page animation
        //        viewModel.currentPageIsRight = true
        //        Task {
        //          try? await Task.sleep(for: .seconds(2))
        //          viewModel.currentPageIsRight = false
        //          try? await Task.sleep(for: .seconds(2))
        //          viewModel.currentPageIsRight = true
        //        }

        // Use this for testing changing page content
//        viewModel.voicePageNumber = 1
//        viewModel.voiceText = "إِنَّ الَّذينَ كَفَروا سَواءٌ عَلَيهِم أَأَنذَرتَهُم أَم لَم تُنذِرهُم لا يُؤمِنونَ"
//        Task {
//          try? await Task.sleep(for: .seconds(0.2))
//          viewModel.voiceText = """
//            إِنَّ الَّذينَ كَفَروا سَواءٌ عَلَيهِم أَأَنذَرتَهُم أَم لَم تُنذِرهُم لا يُؤمِنونَ
//            خَتَمَ اللَّهُ عَلىٰ قُلوبِهِم وَعَلىٰ سَمعِهِم وَعَلىٰ أَبصارِهِم غِشاوَةٌ وَلَهُم عَذابٌ عَظيمٌ
//            وَمِنَ النّاسِ مَن يَقولُ آمَنّا بِاللَّهِ وَبِاليَومِ الآخِرِ وَما هُم بِمُؤمِنينَ
//            يُخادِعونَ اللَّهَ وَالَّذينَ آمَنوا وَما يَخدَعونَ إِلّا أَنفُسَهُم وَما يَشعُرونَ
//            في قُلوبِهِم مَرَضٌ فَزادَهُمُ اللَّهُ مَرَضًا وَلَهُم عَذابٌ أَليمٌ بِما كانوا يَكذِبونَ
//            وَإِذا قيلَ لَهُم لا تُفسِدوا فِي الأَرضِ قالوا إِنَّما نَحنُ مُصلِحونَ
//            أَلا إِنَّهُم هُمُ المُفسِدونَ وَلٰكِن لا يَشعُرونَ
//            وَإِذا قيلَ لَهُم آمِنوا كَما آمَنَ النّاسُ قالوا أَنُؤمِنُ كَما آمَنَ السُّفَهاءُ أَلا إِنَّهُم هُمُ السُّفَهاءُ وَلٰكِن لا يَعلَمونَ
//            وَإِذا لَقُوا الَّذينَ آمَنوا قالوا آمَنّا وَإِذا خَلَوا إِلىٰ شَياطينِهِم قالوا إِنّا مَعَكُم إِنَّما نَحنُ مُستَهزِئونَ
//            اللَّهُ يَستَهزِئُ بِهِم وَيَمُدُّهُم في طُغيانِهِم يَعمَهونَ
//            أُولٰئِكَ الَّذينَ اشتَرَوُا الضَّلالَةَ بِالهُدىٰ فَما رَبِحَت تِجارَتُهُم وَما كانوا مُهتَدينَ
//            """
//        }

        // Use for testing displaying surah number
//        viewModel.voiceText = "اهدِنَا الصِّراطَ المُستَقيمَ"
//        Task {
//          try? await Task.sleep(for: .seconds(0.2))
//          viewModel.voiceText = """
//            اهدِنَا الصِّراطَ المُستَقيمَ
//            صِراطَ الَّذينَ أَنعَمتَ عَلَيهِم غَيرِ المَغضوبِ عَلَيهِم وَلَا الضّالّينَ
//            الم ذٰلِكَ الكِتابُ لا رَيبَ فيهِ هُدًى لِلمُتَّقينَ
//            الَّذينَ يُؤمِنونَ بِالغَيبِ وَيُقيمونَ الصَّلاةَ وَمِمّا رَزَقناهُم يُنفِقونَ
//            وَالَّذينَ يُؤمِنونَ بِما أُنزِلَ إِلَيكَ وَما أُنزِلَ مِن قَبلِكَ وَبِالآخِرَةِ هُم يوقِنونَ
//            أُولٰئِكَ عَلىٰ هُدًى مِن رَبِّهِم وَأُولٰئِكَ هُمُ المُفلِحونَ
//
//            """
//        }

      }
    }
  }

  func scrollToCurrentPage(using proxy: ScrollViewProxy) {
    scrollToPage = viewModel.currentPageIsRight ? "RIGHT" : "LEFT"
    withAnimation {
      proxy.scrollTo(scrollToPage, anchor: .center)
    }
  }

  @ViewBuilder
  private func pageView(pageModel: PageModel, isRight: Bool) -> some View {
    let opacity = 0.5
    let shadowWidth: CGFloat = 4

    HStack(spacing: 4) {
      if !isRight {
        Rectangle()
          .fill(Color.gray.opacity(opacity))
          .frame(width: shadowWidth)
          .padding(.top, 10)
      }
      VStack(alignment: .leading) {
        HStack {
          if pageModel.pageNumber > 0 {
            Text("\(pageModel.pageNumber)")
            Spacer()
            Text(pageModel.surahName)
            Spacer()
            Text("جزء \(pageModel.juzNumber)")
          } else {
            Text(" ")
          }
        }
        .font(.custom("KFGQPC Uthmanic Script", size: 24))
        .padding(.horizontal, 12)
        VStack(alignment: .leading) {
          if viewModel.voicePageNumber == 1 || (isRight && viewModel.voicePageNumber < 3) {
            Spacer()
          }
          Text(pageModel.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
            .padding(8)
          Spacer()
        }
      }
      .frame(maxHeight: .infinity)
      if isRight {
        Rectangle()
          .fill(Color.gray.opacity(opacity))
          .frame(width: shadowWidth)
        .padding(.top, 10)
      }
    }
  }
}


#Preview {
  TwoPagesView(viewModel: MuhaffezViewModel())
}

