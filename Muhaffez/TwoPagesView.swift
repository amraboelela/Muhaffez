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
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.horizontal, 8)
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

