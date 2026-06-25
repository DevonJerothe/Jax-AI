import SwiftUI

public struct PaginatedResultsGridView<Item: Identifiable, Card: View>: View {
    let items: [Item]
    let isLoading: Bool
    let canLoadMore: Bool
    let loadMore: () async -> Void
    let cardBuilder: (Item) -> Card

    @State private var bottomOverscroll: CGFloat = 0
    @State private var didTriggerLoadMore = false

    private let columns: [GridItem] = [
        GridItem(.flexible(maximum: 200), spacing: 16),
        GridItem(.flexible(maximum: 200), spacing: 16),
    ]

    private let threshold: CGFloat = 120

    public var body: some View {
        GeometryReader { geo in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(items) { item in
                        cardBuilder(item)
                    }

                    Color.clear
                        .frame(height: 1)
                        .gridCellColumns(2)
                        .background {
                            GeometryReader { markerGeo in
                                let markerMaxY = markerGeo.frame(in: .named("pageGridScroll")).maxY
                                let overscroll = max(0, geo.size.height - markerMaxY)

                                Color.clear.preference(
                                    key: BottomOverscrollPreferenceKey.self,
                                    value: overscroll
                                )
                            }
                        }
                }
                .padding(.top, 8)
            }
            .coordinateSpace(name: "pageGridScroll")
            .scrollIndicators(.hidden)
            .onPreferenceChange(BottomOverscrollPreferenceKey.self) { value in
                bottomOverscroll = value

                if value < 8 {
                    didTriggerLoadMore = false
                }
            }
            .overlay(alignment: .bottom) {
                PullUpLoadMoreView(
                    progress: min(bottomOverscroll / threshold, 1),
                    isArmed: bottomOverscroll >= threshold,
                    isLoading: isLoading,
                    canLoadMore: canLoadMore
                )
                .padding(.bottom, 12)
            }
            .simultaneousGesture(
                DragGesture().onEnded { _ in
                    guard bottomOverscroll >= threshold else { return }
                    guard !didTriggerLoadMore else { return }
                    guard !isLoading else { return }
                    guard canLoadMore else { return }

                    didTriggerLoadMore = true

                    Task { await loadMore() }
                }
            )
        }
    }
}

private struct BottomOverscrollPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct PullUpLoadMoreView: View {
    @Environment(\.appTheme) private var appTheme

    let progress: CGFloat
    let isArmed: Bool
    let isLoading: Bool
    let canLoadMore: Bool

    private let hiddenOffset: CGFloat = 72

    private var effectiveProgress: CGFloat {
        isLoading ? 1 : progress
    }

    private var effectiveIsArmed: Bool {
        isLoading || isArmed
    }

    var body: some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: effectiveIsArmed ? "arrow.up.circle.fill" : "arrow.up")
                    .font(.title3.weight(.semibold))
                    .rotationEffect(.degrees(effectiveIsArmed ? 180 : 0))
                    .scaleEffect(effectiveIsArmed ? 1.18 : 0.85 + effectiveProgress * 0.15)
                    .foregroundStyle(
                        effectiveIsArmed ? appTheme.tintColor.color : appTheme.secondaryText.color)
            }

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    effectiveIsArmed ? appTheme.primaryText.color : appTheme.secondaryText.color
                )
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background {
            Capsule()
                .fill(appTheme.secondaryBackgroundColor.color)
                .shadow(
                    color: .black.opacity(effectiveIsArmed ? 0.16 : 0.08 * effectiveProgress),
                    radius: effectiveIsArmed ? 14 : 8 * effectiveProgress,
                    y: effectiveIsArmed ? 6 : 3 * effectiveProgress
                )
        }
        .opacity(canLoadMore ? effectiveProgress : 0)
        .offset(y: canLoadMore ? hiddenOffset * (1 - effectiveProgress) : hiddenOffset)
        .scaleEffect(effectiveIsArmed ? 1.06 : 0.92 + effectiveProgress * 0.08)
        .animation(.spring(response: 0.28, dampingFraction: 0.68), value: effectiveIsArmed)
        .animation(.easeOut(duration: 0.16), value: effectiveProgress)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isLoading)
    }

    private var label: String {
        if isLoading {
            return "Loading more..."
        }

        return isArmed ? "Release to load more" : "Pull up to load more"
    }
}
