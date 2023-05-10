#include <QApplication>
#include <QMainWindow>
#include <QLineEdit>
#include <QListWidget>
#include <QListWidgetItem>
#include <QIcon>
#include <Qt>

class MainWindow : public QMainWindow {
public:
    MainWindow() : QMainWindow() {
        // Set window properties
        setFixedSize(320, 480);  // Make window not resizable
        setWindowTitle("New Window");

        // Add text entry at the top
        text_entry = new QLineEdit(this);
        text_entry->setGeometry(0, 0, 320, 30);
        connect(text_entry, SIGNAL(textChanged(const QString&)), this, SLOT(reorder_list(const QString&)));

        // Add scrollable list of text items
        item_list = new QListWidget(this);
        item_list->setGeometry(0, 30, 320, 450);
        item_list->setVerticalScrollBarPolicy(Qt::ScrollBarAsNeeded);  // Or Qt::ScrollBarAlwaysOn or Qt::ScrollBarAlwaysOff

        // Add some sample items to the list
        for (int i = 0; i < 50; i++) {
            QListWidgetItem* item = new QListWidgetItem(QString("Item %1").arg(i+1), item_list);
            item->setIcon(QIcon("firefox.webp")); // set icon
            //item->setTextAlignment(Qt::AlignLeft | Qt::AlignVCenter); // set text alignment
        }

        reorder_list("");
    }

private slots:
    void reorder_list(const QString& search_text) {
        QList<QListWidgetItem*> items;
        for (int i = 0; i < item_list->count(); i++) {
            items.append(item_list->takeItem(0));
        }
        std::sort(items.begin(), items.end(), [](const QListWidgetItem* a, const QListWidgetItem* b) {
            return a->text() < b->text();
        });
        for (auto item : items) {
            item_list->addItem(item);
        }

        QList<QListWidgetItem*> new_items;
        for (int i = 0; i < item_list->count(); i++) {
            QListWidgetItem* item = item_list->takeItem(0);
            if (item != nullptr) {  // Make sure item is not nullptr
                new_items.append(item);
            }
        }

        QList<QListWidgetItem*> matching_items;
        QList<QListWidgetItem*> non_matching_items;

        for (auto item : new_items) {
            if (item->text().toLower().contains(search_text.toLower())) {
                matching_items.append(item);
            } else {
                non_matching_items.append(item);
            }
        }

        QList<QListWidgetItem*> sorted_items = matching_items + non_matching_items;

        for (auto item : sorted_items) {
            item_list->addItem(item);
        }
    }

private:
    QLineEdit* text_entry;
    QListWidget* item_list;
};

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    MainWindow window;
    window.show();
    return app.exec();
}
