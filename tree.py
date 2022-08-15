import sys
from PySide6.QtWidgets import QApplication, QTreeWidget, QTreeWidgetItem

data = {"Project A": ["file_a.py", "file_a.txt", "something.xls"],
        "Project B": ["file_b.csv", "photo.jpg"],
        "Project C": []}

# tree = QTreeWidget()
# tree.setColumnCount(2)
# tree.setHeaderLabels(["Name", "Type"])

class FolderTree(QTreeWidget):
    def __init__(self, parent=None):
        super().__init__(parent=parent)
        self.setColumnCount(1)
        self.setHeaderHidden(True)
        self.children=[]
		

    def addchildren(self,child):

        items = []
        for key, values in data.items():
            item = QTreeWidgetItem([key])
            for value in values:
                ext = value.split(".")[-1].upper()
                child = QTreeWidgetItem([value, ext])
                item.addChild(child)
            items.append(item)
            self.children=items
        self.insertTopLevelItems(0, self.children)
        return self.children


#app = QApplication()
#tree=FolderTree()
#tree.addchildren(data)
#tree.show()
#sys.exit(app.exec())            