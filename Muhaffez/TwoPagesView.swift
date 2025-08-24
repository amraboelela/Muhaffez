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
                if let currentPageIsRight = viewModel.currentPageIsRight {
                    scrollToPage = currentPageIsRight ? "RIGHT" : "LEFT"
                    withAnimation {
                        proxy.scrollTo(scrollToPage, anchor: .center)
                    }
                }
            }
            .onAppear {
                // Use this for testing
//                viewModel.currentPageIsRight = true
//                Task {
//                    try? await Task.sleep(for: .seconds(2))
//                    viewModel.currentPageIsRight = false
//                    //scrollToPage = "LEFT"
//                    try? await Task.sleep(for: .seconds(2))
//                    viewModel.currentPageIsRight = true
//                }
            }
        }
    }

    @ViewBuilder
    private func pageView(pageModel: PageModel, isLeft: Bool) -> some View {
        VStack {
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
                VStack {
                    if viewModel.voicePageNumber == 1 {
                        Spacer()
                    }
                    Text(pageModel.text)
                        .environment(\.layoutDirection, .rightToLeft)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
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
