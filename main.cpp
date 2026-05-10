#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QProcess>
#include <QFile>
#include <QTextStream>
#include <QTextBoundaryFinder>
#include <QStandardPaths>
#include <QAbstractListModel>
#include <QSortFilterProxyModel>
#include <QDir>
#include <QRegularExpression>

struct Emoji {
    QString emoji;
    QString line;
    QString shortcode;
    QStringList tokens;
};

class EmojiModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles { EmojiRole = Qt::UserRole + 1, LineRole };

    int rowCount(const QModelIndex &parent = QModelIndex()) const override {
        return m_data.size();
    }

    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override {
        if (!index.isValid() || index.row() >= m_data.size()) return {};
        const auto &it = m_data.at(index.row());
        if (role == EmojiRole) return it.emoji;
        if (role == LineRole) return it.line;
        return {};
    }

    QHash<int, QByteArray> roleNames() const override {
        return {{EmojiRole, "emoji"}, {LineRole, "line"}};
    }

    void load(const QString &path) {
        beginResetModel();
        m_data.clear();
        QFile f(path);
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            const QRegularExpression re("\\s+");
            while (!ts.atEnd()) {
                QString l = ts.readLine();
                if (l.trimmed().isEmpty()) continue;
                int sp = l.indexOf(' ');
                QString e = (sp > 0) ? l.left(sp) : l;
                QStringList parts = l.toLower().split(re, Qt::SkipEmptyParts);
                QString sc = parts.size() >= 2 ? parts[1] : "";
                QStringList tokens = parts.size() >= 3 ? parts.mid(2) : QStringList();
                m_data.append({e, l, sc, tokens});
            }
        }
        endResetModel();
    }

    const Emoji& get(int row) const { return m_data.at(row); }

private:
    QVector<Emoji> m_data;
};

class FilterModel : public QSortFilterProxyModel {
    Q_OBJECT
public:
    explicit FilterModel(EmojiModel *source, QObject *parent = nullptr)
        : QSortFilterProxyModel(parent), m_source(source) {
        setSourceModel(source);
        setDynamicSortFilter(true);
        sort(0);
    }

    Q_INVOKABLE void setFilter(const QString &query) {
        const QString q = query.trimmed().toLower();
        if (m_query == q) return;
        m_query = q;
        invalidate();
    }

protected:
    bool filterAcceptsRow(int source_row, const QModelIndex &) const override {
        if (m_query.isEmpty()) return true;

        QString qNorm = m_query;
        while (qNorm.startsWith(':')) qNorm.remove(0, 1);
        while (qNorm.endsWith(':')) qNorm.remove(qNorm.size() - 1, 1);
        if (qNorm.isEmpty()) return true;

        const auto &it = m_source->get(source_row);
        if (it.shortcode.contains(qNorm)) return true;
        for (const auto &t : it.tokens) if (t.contains(qNorm)) return true;
        return false;
    }

    bool lessThan(const QModelIndex &left, const QModelIndex &right) const override {
        if (m_query.isEmpty()) return left.row() < right.row();

        auto getScore = [this](const Emoji &it) {
            QString qNorm = m_query;
            while (qNorm.startsWith(':')) qNorm.remove(0, 1);
            while (qNorm.endsWith(':')) qNorm.remove(qNorm.size() - 1, 1);
            if (qNorm.isEmpty()) return 999;

            const QString &sc = it.shortcode;
            QString scBare = sc;
            while (scBare.startsWith(':')) scBare.remove(0, 1);
            while (scBare.endsWith(':')) scBare.remove(scBare.size() - 1, 1);

            if (scBare == qNorm) return 0;
            if (scBare.startsWith(qNorm)) return 1;
            if (scBare.contains(qNorm)) return 2;

            for (const auto &t : it.tokens) {
                if (t == qNorm) return 10;
                if (t.startsWith(qNorm)) return 11;
                if (t.contains(qNorm)) return 20;
            }

            return 999;
        };

        const int s1 = getScore(m_source->get(left.row()));
        const int s2 = getScore(m_source->get(right.row()));
        return (s1 != s2) ? s1 < s2 : left.row() < right.row();
    }
private:
    EmojiModel *m_source;
    QString m_query;
};

class Sys : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool haveKdotool MEMBER m_haveKdotool CONSTANT)
    Q_PROPERTY(bool haveWlCopy MEMBER m_haveWlCopy CONSTANT)
    Q_PROPERTY(bool haveYdotool MEMBER m_haveYdotool CONSTANT)
public:
    Sys() {
        m_haveKdotool = !QStandardPaths::findExecutable("kdotool").isEmpty();
        m_haveWlCopy = !QStandardPaths::findExecutable("wl-copy").isEmpty();
        m_haveYdotool = !QStandardPaths::findExecutable("ydotool").isEmpty();
    }

    Q_INVOKABLE QString cacheListPath() const {
        return QDir::homePath() + "/.cache/emoji-picker/emoji.list";
    }

    Q_INVOKABLE QString runCapture(const QString &cmd) const {
        QProcess p;
        p.start("sh", {"-c", cmd});
        p.waitForFinished();
        return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
    }

    Q_INVOKABLE int run(const QString &cmd) const {
        return QProcess::execute("sh", {"-c", cmd});
    }

    Q_INVOKABLE QString shellQuote(const QString &s) const {
        QString out = s;
        out.replace("'", "'\\''");
        return "'" + out + "'";
    }

    Q_INVOKABLE QString popLastGrapheme(const QString &s) const {
        if (s.isEmpty()) return s;
        QTextBoundaryFinder bf(QTextBoundaryFinder::Grapheme, s);
        bf.toEnd();
        const int start = bf.toPreviousBoundary();
        return (start <= 0) ? QString() : s.left(start);
    }

private:
    bool m_haveKdotool, m_haveWlCopy, m_haveYdotool;
};

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("emoji-picker");

    Sys sys;
    EmojiModel sourceModel;
    sourceModel.load(sys.cacheListPath());

    FilterModel filterModel(&sourceModel);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("Sys", &sys);
    engine.rootContext()->setContextProperty("EmojiModel", &filterModel);

    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    return engine.rootObjects().isEmpty() ? 1 : app.exec();
}

#include "main.moc"
