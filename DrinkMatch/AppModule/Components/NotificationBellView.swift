import SwiftUI

/// Bell icon with an unread-count badge; opens a popover listing every
/// in-app notification, newest first.
struct NotificationBellView: View {
    var notifications: [AppNotification]
    var onOpen: () -> Void

    @State private var isOpen = false

    private var unreadCount: Int { notifications.filter { !$0.read }.count }

    var body: some View {
        Button {
            isOpen.toggle()
            if isOpen { onOpen() }
        } label: {
            ZStack(alignment: .topTrailing) {
                Text("🔔").font(.system(size: 14))
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: 0x12100A))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Theme.red)
                        .clipShape(Capsule())
                        .offset(x: 10, y: -8)
                }
            }
            .fixedSize()
        }
        .buttonStyle(BoardChromeButtonStyle())
        .popover(isPresented: $isOpen) {
            NotificationListView(notifications: notifications)
                .frame(width: 280)
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct NotificationListView: View {
    var notifications: [AppNotification]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if notifications.isEmpty {
                    Text("通知はありません")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                } else {
                    // Pre-sorted newest-first by the server (`order by
                    // created_at desc` in SupabaseRepository.fetchNotifications).
                    ForEach(notifications) { notification in
                        Text(notification.body)
                            .font(.system(size: 12))
                            .foregroundStyle(notification.read ? Theme.muted : Theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .overlay(Divider().background(Theme.divider), alignment: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: 300)
        .background(Theme.card)
    }
}
