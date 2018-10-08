import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    // для функции objectSelected
    // хранится та нода, которая была выбрана пользователем
    var selectedNode: SCNNode?
    
    // для функции undoLastObject
    // узлы которые размещены пользователем (объекты)
    var placedNodes = [SCNNode]()
    // узлы nodes которые были добавлены когда произошла визуализация (массив поверхностей)
    var planeNodes = [SCNNode]()
    
    @IBOutlet var sceneView: ARSCNView!
    let configuration = ARWorldTrackingConfiguration()
    
    // Вариант нашего объекта
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    // Хранит 1 из 3 вариантов того, каким образом
    // мы размещаем объекты
    // Метод changeObjectMode меняет эту переменную
    // И дальше по этой переменной можем смотреть когда
    // размещаем объект
    
    // так как мы знаем что при изменение objectMode у нас меняется само свойство objectMode то мы можем привязаться
    // к этому свойству
    // делаем наблюдателя didSet
    var objectMode: ObjectPlacementMode = .freeform {
        
        // после того как установилось значение objectMode вызываем reloadConfiguration
        didSet {
            reloadConfiguration()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // параметры не нужны потому что конфигурация будет загружаться в зависимости от состояния
    // свойсва objectMode
    
    // определить нужно ли нам определять картинки или не нужно
    func reloadConfiguration() {
        // определят поверхности
        configuration.planeDetection = [.horizontal, .vertical]
        // тернальным оператором воспользуемся, сравним если у нас objectMode == .image
        // тогда нужно присвоить свойству configuration.detectionImages
        configuration.detectionImages = (objectMode == .image) ? ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) : nil
        
        // cама перезагрузка
        sceneView.session.run(configuration)
        
        // и должны эту функцию вызвать из viewWillAppear потому что image может быть выбранно не только в начале
    }

    // Вызывается когда мы нажимаем на SegmentedControl
    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            // просто добавить на сцену
            objectMode = .freeform
        case 1:
            // привязать к поверхности
            objectMode = .plane
        case 2:
            // привязать к ранее распознанному изубражению
            objectMode = .image
        default:
            break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // идентификатор нашего перехода к другому storyboard
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            // делегатом оставляем себя
            optionsViewController.delegate = self
            optionsViewController.preferredContentSize = CGSize(width: 250, height: 250)
        }
    }
    
    // Работает когда пользователь касается
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        // подтвердить что та нода которую мы запомнили существует
        guard let node = selectedNode, let touch = touches.first else { return }
        
        // в зависимости от свойств которые мы задавали
        switch objectMode {
        case .freeform: addNodeInFront(node)
        case  .plane: break
        case .image: break
            
            // теперь создадим метод который совместит где то объект когда мы нажимаем на freeform
        }
        
    } // touchesBegan
    
    func addNodeInFront(_ node: SCNNode) {
        // добавить ноду перед камерой // пример с корзиной // AR House
        guard let currentFrame = sceneView.session.currentFrame else { return }
        // создать некую матрицу которая при перемножении будет располагать наш
        // объект в 20 см от нашей камеры
        var translation = matrix_identity_float4x4
        
        // изменить у этой матрицы колонку которая отвечает за координаты ( 3 колонка )
        translation.columns.3.z = -0.2
        
        // node.simdTransform == node.transform только новее
        // матрица 4х4 которая однозначно определяет где наша камера находится
        // как она повернута и прочее
        // translation - отодвигает точку на 20 см
        
        node.simdTransform =
            matrix_multiply(currentFrame.camera.transform, translation)
        
        addNodeToScheneRoot(node)
        
    } // addNodeInFront
    
    // клонирует и размещает наш объект на сцене
    func addNodeToScheneRoot(_ node: SCNNode) {
        
        // если мы на сцену добавим эту то единственное что наши объекты передаются по ссылкe
        // то у нас добавится та же нода которая передавалась и соответственно
        // если мы много будем передавать объектов то они у нас будут скакать
        // т.е. мы передали ноду, добавили и у нас старая нода исчезла
        // т.е. пользователь нажал в одном месте появился объект, потом
        // передвинул телефон нажал в другом месте у него объект опять появился
        // а тот старый исчез поэтому нам надо ее клонировать
        
        let cloneNode = node.clone()
        sceneView.scene.rootNode.addChildNode(cloneNode)
        
        placedNodes.append(cloneNode)
        
    } // addNodeToScheneRoot
    
    // функция делает тоже самое что и addNodeToScheneRoot только он будет добавлять не внутрь rootnode
    // а parentNode
    func addNode(_ node: SCNNode, toImageUsingParentNode parentNode: SCNNode) {
        
        let cloneNode = node.clone()
        parentNode.addChildNode(cloneNode)
        placedNodes.append(cloneNode)
    }
    
    // вызывается когда добавляется якорь когда произошло какое то событие связанное с определением того, что у нас нашелся
    // либо plane либо image
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        if let imageAnchor = anchor as? ARImageAnchor {
            
            nodeAdded(node, for: imageAnchor)
            
        } else if let planeAnchor = anchor as? ARPlaneAnchor {
            
            nodeAdded(node, for: planeAnchor)
        }
    }
    
    // вызывается когда обнаруживает что поверхность у нас обновилась
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // проверим что получили planeAnchor и получили первую ноду
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let geometry = planeNode.geometry as? SCNPlane else { return }
        
        // geometry получили, plane получили
        // изменить ее позицию
        // сдвигаем в центр planeAnchor
        planeNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
        // изменили размер
        geometry.width = CGFloat(planeAnchor.extent.x)
        geometry.height = CGFloat(planeAnchor.extent.z)
    
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
    
        // Чтобы нам разрешить определение поверхностей нужно разрешить
        // свойсвто PlaneAnchor либо vetrical либо gorizontal либо оба
        // идем в reloadConfiguration
        
        // затем создаем плоскость
        let floor = createFloor(planeAnchor: anchor)
        node.addChildNode(floor)
        planeNodes.append(floor)
        
        
    }
    
    func createFloor(planeAnchor: ARPlaneAnchor) -> SCNNode {
        let node = SCNNode()
        let geometry = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.y))
        node.geometry = geometry

        
        node.opacity = 0.25
        node.eulerAngles.x = .pi/2
        return node
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor) {
        // используем метод который не в root добавляет а куда то в конкретнное место
        
        // проверяем выбранна ли у нас нода
        // если да то ее добавляем к этой ноде которую мы сюда передаем которую нам передал renderer
        // и на нашей картинке получится объект
        if let selectedNode = selectedNode {
            // в тот node который у нас сюда передается мы добаляем который связан с anchor мы добавляем node который задан
            addNode(selectedNode, toImageUsingParentNode: node)
        }
    }
    
    // Но поиск картинок затратная вещь и нам не нужно чтобы это происходило постоянно
    // а только тогда когда у нас из menu выбранно что мы хотим искать картинки
    // Мы можем в любой момент менять нашу конфигурацию
    // Добавим функци которая перезагрузит конфигурацию reloadConfiguration
    
    
    
} // сlass

extension ViewController: OptionsViewControllerDelegate {
    
    // Вызывается когда пользователь выбирает форму, цвет, размер
    func objectSelected(node: SCNNode) {
        dismiss(animated: true, completion: nil)
        
        // После того как мы вызвали объект нам нужно сохранить информацию о том, какой это объект
        selectedNode = node
        
        // Сделать нажатие пользователя
    }
    
    // Когда юзер тапает "Enable/Disable Plane Visualization"
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
    }
    
    // Когда юзер тапает "Undo Last Shape"
    // Удалялся последний размещенный объект
    func undoLastObject() {
        
    }
    
    // Когда юзер тапает "Reset Scene"
    func resetScene() {
        dismiss(animated: true, completion: nil)
    }
}
