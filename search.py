import sys
from PySide2.QtWidgets import QApplication, QMainWindow, QLineEdit, QListWidget, QListWidgetItem
from PySide2.QtCore import Qt
from PySide2.QtGui import QIcon

class MainWindow(QMainWindow):

    def __init__(self):
        super().__init__()

        # Set window properties
        self.setFixedSize(320, 480)  # Make window not resizable
        self.setWindowTitle("New Window")

        # Add text entry at the top
        self.text_entry = QLineEdit(self)
        self.text_entry.setGeometry(0, 0, 320, 30)
        self.text_entry.textChanged.connect(self.reorder_list)

        # Add scrollable list of text items
        self.item_list = QListWidget(self)
        self.item_list.setGeometry(0, 30, 320, 450)
        self.item_list.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)  # Or Qt.ScrollBarAlwaysOn or Qt.ScrollBarAlwaysOff

        # Add some sample items to the list
        for i in range(50):
            item = QListWidgetItem("Item {}".format(i+1))
            item.setIcon(QIcon("firefox.webp")) # set icon
            #item.setTextAlignment(Qt.AlignLeft | Qt.AlignVCenter) # set text alignment
            self.item_list.addItem(item)

        self.reorder_list()

    def reorder_list(self, search_text=""):
        items = []
        for i in range(self.item_list.count()):
            items.append(self.item_list.takeItem(0))
        items.sort(key=lambda x: x.text())
        for item in items:
            self.item_list.addItem(item)

        for i in range(self.item_list.count()):
            item = self.item_list.takeItem(0)
            if item is not None:  # Make sure item is not None
                items.append(item)

        matching_items = []
        non_matching_items = []

        for item in items:
            if search_text.lower() in item.text().lower():
                matching_items.append(item)
            else:
                non_matching_items.append(item)

        new_items = matching_items + non_matching_items

        for item in new_items:
            self.item_list.addItem(item)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())