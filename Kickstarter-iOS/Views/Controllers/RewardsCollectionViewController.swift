import Foundation
import Library
import KsApi
import Prelude

final class RewardsCollectionViewController: UICollectionViewController {
  private let dataSource = RewardsCollectionViewDataSource()
  private let viewModel = RewardsCollectionViewModel()

  // Hidden scroll view used for paging
  private let hiddenPagingScrollView: UIScrollView = {
    UIScrollView()
      |> \.isPagingEnabled .~ true
      |> \.isHidden .~ true
  }()

  private let layout: UICollectionViewFlowLayout = {
    UICollectionViewFlowLayout()
      |> \.minimumLineSpacing .~ Styles.grid(3)
      |> \.minimumInteritemSpacing .~ 0
      |> \.sectionInset .~ .init(topBottom: Styles.grid(6))
      |> \.scrollDirection .~ .horizontal
  }()

  private var flowLayout: UICollectionViewFlowLayout? {
    return self.collectionViewLayout as? UICollectionViewFlowLayout
  }

  static func instantiate(with project: Project, refTag: RefTag?) -> RewardsCollectionViewController {
    let rewardsCollectionVC = RewardsCollectionViewController()
    rewardsCollectionVC.viewModel.inputs.configure(with: project, refTag: refTag)

    return rewardsCollectionVC
  }

  init() {
    super.init(collectionViewLayout: layout)

    let closeButton = UIBarButtonItem(image: UIImage(named: "icon--cross"),
                                      style: .plain,
                                      target: self,
                                      action: #selector(closeButtonTapped))

    _ = closeButton
      |> \.width .~ Styles.minTouchSize.width
      |> \.accessibilityLabel %~ { _ in Strings.Dismiss() }

    _ = self
      |> \.title %~ { _ in Strings.Back_this_project() }

    self.navigationItem.setLeftBarButton(closeButton, animated: false)
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    _ = self.collectionView
      |> \.dataSource .~ dataSource

    self.collectionView.register(RewardCell.self)

    self.configureHiddenScrollView()

    self.viewModel.inputs.viewDidLoad()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    guard let layout = self.flowLayout else { return }

    layout.itemSize = self.calculateItemSize(from: layout, using: self.collectionView)

    self.updateHiddenScrollViewBoundsIfNeeded()
  }

  override func bindStyles() {
    super.bindStyles()

    _ = self.view
      |> \.backgroundColor .~ .ksr_grey_200

    _ = self.collectionView
      |> collectionViewStyle

    _ = self.collectionView.panGestureRecognizer
      |> \.isEnabled .~ false
  }

  override func bindViewModel() {
    super.bindViewModel()

    self.viewModel.outputs.reloadDataWithRewards
      .observeForUI()
      .observeValues { [weak self] rewards in
        self?.dataSource.load(rewards: rewards)
        self?.collectionView.reloadData()
    }
  }

  // MARK: - Private Helpers

  private func configureHiddenScrollView() {
    _ = self.hiddenPagingScrollView
      |> \.delegate .~ self

    _ = (self.hiddenPagingScrollView, self.view)
      |> ksr_addSubviewToParent()

    self.view.sendSubviewToBack(self.hiddenPagingScrollView)

    self.collectionView.addGestureRecognizer(self.hiddenPagingScrollView.panGestureRecognizer)
  }

  private func updateHiddenScrollViewBoundsIfNeeded() {
    guard let layout = flowLayout else { return }

    let (contentSize, pageSize, contentInsetLeftRight) = self.hiddenScrollViewData(from: layout,
                                                                                   using: self.collectionView)
    let needsUpdate = self.collectionView.contentInset.left != contentInsetLeftRight

    // Check if orientation or frame has changed
    if needsUpdate {
      _ = self.hiddenPagingScrollView
        |> \.frame .~ self.collectionView.frame
        |> \.bounds .~ CGRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)
        |> \.contentSize .~ CGSize(width: contentSize.width, height: contentSize.height)

      let (top, bottom) = self.collectionView.contentInset.topBottom

      _ = self.collectionView
        |> \.contentInset .~ .init(top: top,
                                   left: contentInsetLeftRight,
                                   bottom: bottom,
                                   right: contentInsetLeftRight)

      self.collectionView.contentOffset.x = -contentInsetLeftRight
    }
  }

  typealias HiddenScrollViewData = (contentSize: CGSize, pageSize: CGSize, contentInsetLeftRight: CGFloat)

  private func hiddenScrollViewData(from layout: UICollectionViewFlowLayout,
                                    using collectionView: UICollectionView) -> HiddenScrollViewData {
    let numberOfItemsInCollectionView = self.collectionView.numberOfItems(inSection: 0)
    let itemSize = layout.itemSize
    let lineSpacing = layout.minimumLineSpacing
    let totalItemWidth = itemSize.width + lineSpacing

    let pageWidth = totalItemWidth
    let pageHeight = itemSize.height
    let pageSize = CGSize(width: pageWidth, height: pageHeight)

    let contentWidth = (CGFloat(numberOfItemsInCollectionView) * totalItemWidth) - lineSpacing
    let contentHeight = pageHeight
    let contentSize = CGSize(width: contentWidth, height: contentHeight)

    let contentInsetLeftRight = (collectionView.frame.width - itemSize.width) / 2

    return (contentSize, pageSize, contentInsetLeftRight)
  }

  private func calculateItemSize(from layout: UICollectionViewFlowLayout,
                                 using collectionView: UICollectionView) -> CGSize {
    let cardWidth: CGFloat = RewardCell.fixedCardWidth

    let sectionInsets = layout.sectionInset
    let topBottomInsets = sectionInsets.top + sectionInsets.bottom
    let leftRightInsets = sectionInsets.left + sectionInsets.right

    let itemHeight = collectionView.contentSize.height - topBottomInsets
    let itemWidth = cardWidth - leftRightInsets

    return CGSize(width: itemWidth, height: itemHeight)
  }

  // MARK: - Public Functions
  @objc func closeButtonTapped() {
    self.navigationController?.dismiss(animated: true, completion: nil)
  }
}

extension RewardsCollectionViewController {
  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard scrollView == self.hiddenPagingScrollView else { return }

    let leftInset = self.collectionView.contentInset.left

    self.collectionView.contentOffset.x = scrollView.contentOffset.x - leftInset
  }
}

// MARK: Styles
private var collectionViewStyle = { collectionView -> UICollectionView in
  collectionView
    |> \.backgroundColor .~ .ksr_grey_200
    |> \.clipsToBounds .~ false
    |> \.allowsSelection .~ true
}
