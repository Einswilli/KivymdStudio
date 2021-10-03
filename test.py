from PyQt5.QtWidgets import QApplication, QMainWindow, QTreeView
from PyQt5.Qt import QStandardItemModel, QStandardItem
from PyQt5.QtQml import qmlRegisterType, QQmlComponent, QQmlEngine
from PyQt5.QtGui import QFont, QColor
from functools import partial
import os
from pathlib import Path
import sys
from PySide2.QtCore import *
from PySide2.QtGui import *
from PySide2.QtWidgets import * 
from pathlib import Path

class DisplayablePath(object):
    display_filename_prefix_middle = '├──'
    display_filename_prefix_last = '└──'
    display_parent_prefix_middle = '    '
    display_parent_prefix_last = '│   '

    def __init__(self, path, parent_path, is_last):
        self.path = Path(str(path))
        self.parent = parent_path
        self.is_last = is_last
        if self.parent:
            self.depth = self.parent.depth + 1
        else:
            self.depth = 0

    @property
    def displayname(self):
        if self.path.is_dir():
            return self.path.name + '/'
        return self.path.name

    @classmethod
    def make_tree(cls, root, parent=None, is_last=False, criteria=None):
        root = Path(str(root))
        criteria = criteria or cls._default_criteria

        displayable_root = cls(root, parent, is_last)
        yield displayable_root

        children = sorted(list(path
                               for path in root.iterdir()
                               if criteria(path)),
                          key=lambda s: str(s).lower())
        count = 1
        for path in children:
            is_last = count == len(children)
            if path.is_dir():
                yield from cls.make_tree(path,
                                         parent=displayable_root,
                                         is_last=is_last,
                                         criteria=criteria)
            else:
                yield cls(path, displayable_root, is_last)
            count += 1

    @classmethod
    def _default_criteria(cls, path):
        return True

    @property
    def displayname(self):
        if self.path.is_dir():
            return self.path.name + '/'
        return self.path.name

    def displayable(self):
        if self.parent is None:
            return self.displayname

        _filename_prefix = (self.display_filename_prefix_last
                            if self.is_last
                            else self.display_filename_prefix_middle)

        parts = ['{!s} {!s}'.format(_filename_prefix,
                                    self.displayname)]

        parent = self.parent
        while parent and parent.parent is not None:
            parts.append(self.display_parent_prefix_middle
                         if parent.is_last
                         else self.display_parent_prefix_last)
            parent = parent.parent

        return ''.join(reversed(parts))

    def listTree(self):
        pass


class StandardItem(QStandardItem):
    def __init__(self, txt='', font_size=12, set_bold=False, color=QColor(0, 0, 0)):
        super().__init__()

        fnt = QFont('Open Sans', font_size)
        fnt.setBold(set_bold)

        self.setEditable(False)
        self.setForeground(color)
        self.setFont(fnt)
        self.setText(txt)



class FolderTree(QMainWindow):
    def __init__(self):
        super().__init__()

        tree=QTreeView()
        tree.setHeaderHidden(True)
        self.elements=[]
        self.rootName=''
        treeModel=QStandardItemModel()
        self.treeNode=treeModel.invisibleRootItem()

        self.root=StandardItem(self.rootName,16)

        root=StandardItem('America',16)
        a=StandardItem('America',16)
        b=StandardItem('America',16)
        c=StandardItem('America',16)
        d=StandardItem('America',16)
        e=StandardItem('America',16)
        f=StandardItem('America',16)

        a.appendRow(b)
        b.appendRow(c)
        d.appendRow(e)
        d.appendRow(f)
        root.appendRow(a)
        root.appendRow(d)
        self.treeNode.appendRow(root)
        tree.setModel(treeModel)
        tree.expandAll()
        tree.show()
        self.setCentralWidget(tree)
        #self.r.addwidget(self.tree)

    def tree_to_dict(self,path_):
        file_token = ''
        for root, dirs, files in os.walk(path_):
            tree = {d: self.tree_to_dict(os.path.join(root, d)) for d in dirs}
            tree.update({f: file_token for f in files})
            return  tree  # note we discontinue iteration trough os.walk
    
    def addChildren(self,path):
        t=self.tree_to_dict(path)
        r=StandardItem(str(path).split('/')[-1],16)
        for k in t:
            r.appendRow(StandardItem(k))
        self.root.appendRow(r)
        self.treeNode.appendRow(self.root)
        


app = QApplication(sys.argv)
engine = QQmlEngine()
#qmlRegisterType(FolderTree,'DotPy.FolderTreeView' , 1, 0, 'FolderTree')
component = QQmlComponent(engine)
#component.loadUrl(QUrl('example.qml'))
#f=FolderTree()
#print(f.tree_to_dict('/root/Images/'))
#f.addChildren('/root/Images')
#f.show()
sys.exit(app.exec_())

