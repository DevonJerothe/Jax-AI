import UIKit
import SwiftUI 
import Collections 


public struct ReorderableGridView<Key: Hashable, Value, Content: View>: UIViewControllerRepresentable {

    @Binding private var data: OrderedDictionary<Key, Value>
    private let columns: Int
    private let interItem: CGFloat 
    private let interGroup: CGFloat
    private let sectionInsets: CGFloat
    private let contentBuilder: (Key, Binding<Value>) -> Content
    private let onHeightChanged: ((CGFloat) -> Void)?

    private let onDraggingChange: ((Bool) -> Void)?

    public init(
        data: Binding<OrderedDictionary<Key, Value>>,
        columns: Int = 2,
        interItem: CGFloat = 16,
        interGroup: CGFloat = 16,
        sectionInsets: CGFloat = 16,
        onHeightChanged: ((CGFloat) -> Void)? = nil,
        onDraggingChange: ((Bool) -> Void)? = nil,
        @ViewBuilder contentBuilder: @escaping (Key, Binding<Value>) -> Content
    ) {
        self._data = data 
        self.columns = columns 
        self.interItem = interItem 
        self.interGroup = interGroup 
        self.sectionInsets = sectionInsets 
        self.onHeightChanged = onHeightChanged
        self.onDraggingChange = onDraggingChange
        self.contentBuilder = contentBuilder 
    }

    public func makeUIViewController(context: Context) -> ReorderableGridViewController<Key, Value, Content> {
        let vc = ReorderableGridViewController(
            data: data,
            columns: columns,
            interItem: interItem,
            interGroup: interGroup,
            sectionInsets: sectionInsets,
            contentBuilder: contentBuilder
        )
        vc.onDataChanged = { newData in 
            self.data = newData
        }
        vc.onHeightChanged = onHeightChanged
        vc.onDraggingChange = onDraggingChange
        return vc
    }

    public func updateUIViewController(_ uiViewController: ReorderableGridViewController<Key, Value, Content>, context: Context) {
        uiViewController.data = data 
    }
}

public class ReorderableGridViewController<Key: Hashable, Value, Content: View>: UIViewController, UICollectionViewDragDelegate, UICollectionViewDropDelegate {

    var isReordering: Bool = false 
    var needsSnapshotUpdate: Bool = false 
    var data: OrderedDictionary<Key, Value> {
        didSet {
            if isReordering {
                needsSnapshotUpdate = true 
            } else {
                applySnapshot(animated: true) 
            }
        }
    }

    var onDataChanged: ((OrderedDictionary<Key, Value>) -> Void)?
    var onHeightChanged: ((CGFloat) -> Void)?
    var onDraggingChange: ((Bool) -> Void)?

    private var collectionView: UICollectionView! 
    private var dataSource: UICollectionViewDiffableDataSource<Int, Key>! 

    private let columns: Int 
    private let interItem: CGFloat 
    private let interGroup: CGFloat 
    private let sectionInsets: CGFloat
    private let contentBuilder: (Key, Binding<Value>) -> Content 

    init(
        data: OrderedDictionary<Key, Value>,
        columns: Int,
        interItem: CGFloat,
        interGroup: CGFloat,
        sectionInsets: CGFloat,
        @ViewBuilder contentBuilder: @escaping (Key, Binding<Value>) -> Content
    ) {
        self.data = data 
        self.columns = columns 
        self.interItem = interItem 
        self.interGroup = interGroup 
        self.sectionInsets = sectionInsets 
        self.contentBuilder = contentBuilder 
        
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // setup 
        setupCollectionView()
        setupDataSource()
        applySnapshot(animated: false)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        notifyHeightChanged()
    }

    private func setupCollectionView() {
        let layout = makeLayout(columns: columns, interItem: interItem, interGroup: interGroup, sectionInsets: sectionInsets)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false 
        collectionView.backgroundColor = .clear 
        collectionView.dragInteractionEnabled = true 
        collectionView.isScrollEnabled = false 
        collectionView.reorderingCadence = .immediate 

        // collectionView.dragDelegate = self 
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    public func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        onDraggingChange?(true) 
        let key = Array(data.keys)[indexPath.item]
        let item = UIDragItem(itemProvider: NSItemProvider(object: String(describing: key) as NSString))
        item.localObject = key 
        return [item]
    }

    public func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    public func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        onDraggingChange?(false) 
    }

    public func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: any UICollectionViewDropCoordinator) {
        guard coordinator.proposal.operation == .move else { return }

        let destination: IndexPath = coordinator.destinationIndexPath ?? IndexPath(item: max(collectionView.numberOfItems(inSection: 0) - 1, 0), section: 0)
        if let item = coordinator.items.first, item.sourceIndexPath != nil {
            coordinator.drop(item.dragItem, toItemAt: destination)
        }
    }


    private func setupDataSource() {
        let cellReg = UICollectionView.CellRegistration<UICollectionViewCell, Key> { [weak self] cell, _, key in 
            guard let self = self else { return }

            let initialValue = self.data[key]
            let binding = Binding<Value>(
                get: { [weak self] in 
                    guard let self, let v = self.data[key] else { return initialValue! }
                    return v 
                },
                set: { [weak self] newValue in 
                    guard let self else { return }
                    self.data[key] = newValue 
                    self.onDataChanged?(self.data) 
                    self.notifyHeightChanged()
                }
            )

            cell.contentConfiguration = UIHostingConfiguration {
                self.contentBuilder(key, binding) 
            }
        }
        dataSource = UICollectionViewDiffableDataSource<Int, Key>(collectionView: collectionView) { collectionView, indexPath, key in 
            collectionView.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: key)
        }

        collectionView.dataSource = dataSource 
        collectionView.dragDelegate = self 
        collectionView.dropDelegate = self 

        dataSource.reorderingHandlers.canReorderItem = { _ in true }
        dataSource.reorderingHandlers.didReorder = { [weak self] transaction in 
            guard let self = self else { return }

            self.isReordering = true

            let orderedKeys = self.dataSource.snapshot().itemIdentifiers
            var newOD = OrderedDictionary<Key, Value>()
            for k in orderedKeys {
                if let v = self.data[k] { newOD[k] = v }
            }
            self.data = newOD
            print("data changed: \(self.data)")
            self.onDataChanged?(self.data)

            self.isReordering = false 

            if self.needsSnapshotUpdate {
                self.needsSnapshotUpdate = false 
                DispatchQueue.main.async { [weak self] in 
                    self?.applySnapshot(animated: true)
                    self?.notifyHeightChanged()
                }
            }
        }
    }

    private func applySnapshot(animated: Bool) {
        var snap = NSDiffableDataSourceSnapshot<Int, Key>()
        snap.appendSections([0])
        let keys = Array(data.keys)

        // Skip if no changes
        if dataSource.snapshot().itemIdentifiers == keys { return }
        
        snap.appendItems(keys)
        dataSource.apply(snap, animatingDifferences: animated) { [weak self] in 
            self?.notifyHeightChanged()
        }
    }

    private func makeLayout(columns: Int, interItem: CGFloat, interGroup: CGFloat, sectionInsets: CGFloat) -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(130))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(130))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
        group.interItemSpacing = .fixed(interItem)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = interGroup
        section.contentInsets = .init(top: sectionInsets, leading: sectionInsets, bottom: sectionInsets, trailing: sectionInsets)

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func notifyHeightChanged() {
        view.layoutIfNeeded()
        collectionView.layoutIfNeeded() 
        let height = collectionView.collectionViewLayout.collectionViewContentSize.height + collectionView.contentInset.top + collectionView.contentInset.bottom 
        onHeightChanged?(height)
    }
}



