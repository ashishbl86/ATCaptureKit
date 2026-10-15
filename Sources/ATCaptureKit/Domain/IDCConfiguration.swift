import SwiftUI

public struct IDCCaptureCopy {
    public var title: String?
    public var subtitle: String?
    public var eyebrow: String?

    public init(title: String? = nil, subtitle: String? = nil, eyebrow: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.eyebrow = eyebrow
    }
}

public enum IDCProgressStyle {
    case segments(count: Int, filled: Int)
    case fraction(Double)
    case hidden
}

struct IDCSkipOption {
    var title: String
    var appearsAfter: TimeInterval
    var appearsAfterRejections: Int

    init(
        title: String = IDCStrings.CTA.skip,
        appearsAfter: TimeInterval = 10,
        appearsAfterRejections: Int = 2
    ) {
        self.title = title
        self.appearsAfter = appearsAfter
        self.appearsAfterRejections = appearsAfterRejections
    }
}

enum IDCScanTopBarPlacement {
    case standard
    case embeddedSheet
}

public struct IDCConfiguration {
    var pieces: [IDCPiece]
    var flowTitle: String?
    var resolvedFlowTitle: String { flowTitle ?? IDCStrings.Flow.defaultTitle }
    public var copy: [IDCPiece: IDCCaptureCopy] = [:]
    public var progress: IDCProgressStyle = .segments(count: 4, filled: 1)
    public var showsBack: Bool = true
    public var allowUploadFromDevice: Bool = true
    var showsScanTopBar: Bool = true
    var scanTopBarPlacement: IDCScanTopBarPlacement = .standard
    var scanTopBarTrailingSystemImage: String?
    var onScanTopBarTrailingTap: (() -> Void)?
    public var headerAccessory: AnyView?
    var showsReminderLink: Bool = true
    var skip: IDCSkipOption?
    var analyticsSubjectId: String?
    var reminderLinkRevealNanoseconds: UInt64 = IDCTheme.Animation.reminderLinkRevealNanoseconds
    var onReminderSet: ((Date) -> Void)?
    var selfieSubjectName: String?
    let analyticsContext: String
    #if DEBUG
    var debugSimulateCameraDenied: Bool = false
    var debugSimulateCameraPrimer: Bool = false
    var debugRevealsReminderLinkImmediately: Bool = false
    #endif

    public init(pieces: [IDCPiece], flowTitle: String? = nil, analyticsContext: String) {
        self.pieces = pieces
        self.flowTitle = flowTitle
        self.analyticsContext = analyticsContext
    }

    func copy(for piece: IDCPiece) -> IDCCaptureCopy {
        copy[piece] ?? IDCCaptureCopy()
    }

    var scanTopBarBaseTopPadding: CGFloat {
        switch scanTopBarPlacement {
        case .standard:
            return IDCTheme.Layout.topBarTopPadding
        case .embeddedSheet:
            return IDCTheme.Layout.embeddedSheetTopBarTopPadding
        }
    }

    var scanTopBarIncludesSafeAreaTop: Bool {
        scanTopBarPlacement == .embeddedSheet
    }

    var isCompactHost: Bool {
        scanTopBarPlacement == .embeddedSheet
    }

    var headerTopPadding: CGFloat {
        isCompactHost ? IDCTheme.Layout.compactHeaderTopPadding : IDCTheme.Layout.headerTopPadding
    }

    var viewfinderTopPadding: CGFloat {
        isCompactHost ? IDCTheme.Layout.compactViewfinderTopPadding : IDCTheme.Layout.viewfinderTopPadding
    }

    var selfieScannerTopPadding: CGFloat {
        isCompactHost ? IDCTheme.Layout.compactSelfieScannerTopPadding : IDCTheme.Layout.selfieScannerTopPadding
    }

    var footerMinHeight: CGFloat {
        isCompactHost ? IDCTheme.Layout.compactFooterMinHeight : IDCTheme.Layout.footerMinHeight
    }
}
