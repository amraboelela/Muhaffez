//
//  TwoPagesView.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/24/25.
//

import SwiftUI

struct TwoPagesView: View {
    @State var viewModel: MuhaffezViewModel
    @State private var scrollToPage: String? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    pageView(pageModel: viewModel.leftPage, isLeft: true)
                        .padding(.leading, 4)
                        .frame(width: UIScreen.main.bounds.width)
                        .id("LEFT")
                    pageView(pageModel: viewModel.rightPage, isLeft: false)
                        .padding(.trailing, 4)
                        .frame(width: UIScreen.main.bounds.width)
                        .id("RIGHT")
                }
            }
            .onChange(of: viewModel.currentPageIsRight) {
                scrollToPage = viewModel.currentPageIsRight ? "RIGHT" : "LEFT"
                withAnimation {
                    proxy.scrollTo(scrollToPage, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo("RIGHT", anchor: .center)
                // Use this for testing
//                viewModel.currentPageIsRight = true
//                Task {
//                    try? await Task.sleep(for: .seconds(2))
//                    viewModel.currentPageIsRight = false
//                    try? await Task.sleep(for: .seconds(2))
//                    viewModel.currentPageIsRight = true
//                }

//                viewModel.voicePageNumber = 1
//                viewModel.foundAyat = [1]
//                viewModel.matchedWords = [("الحَمدُ", true), ("لِلَّهِ", true), ("رَبِّ", true), ("العالَمينَ", true), ("الرَّحمٰنِ", false), ("الرَّحيمِ", false), ("مالِكِ", true), ("يَومِ", true) ]
            }
        }
    }

    @ViewBuilder
    private func pageView(pageModel: PageModel, isLeft: Bool) -> some View {
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
            .font(.headline)
            .padding(.horizontal, 12)
            HStack(spacing: 4) {
                if isLeft {
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 2)
                        .padding(.vertical, 8)
                }
                VStack(alignment: .leading) {
                    if viewModel.voicePageNumber == 1 {
                        Spacer()
                    }
                    Text(pageModel.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, .rightToLeft)
                        .padding(8)
                    Spacer()
                }
                .border(Color.gray)
                if !isLeft {
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 2)
                        .padding(.vertical, 8)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}


#Preview {
    TwoPagesView(viewModel: MuhaffezViewModel())
}
