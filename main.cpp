#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QProcess>
#include <QFile>
#include <QTextStream>
#include <QStandardPaths>

class Sys : public QObject {
    Q_OBJECT
public:
    Q_INVOKABLE QString cacheListPath() const {
        const QString home = qEnvironmentVariable("HOME");
        return home + "/.cache/emoji-picker/emoji.list";
    }

    Q_INVOKABLE QString readAllText(const QString &path) const {
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
            return QString();
        QTextStream ts(&f);
        ts.setEncoding(QStringConverter::Utf8);
        return ts.readAll();
    }

    Q_INVOKABLE bool commandExists(const QString &cmd) const {
        return QProcess::execute("sh", {"-lc", "command -v " + cmd + " >/dev/null 2>&1"}) == 0;
    }

    Q_INVOKABLE QString runCapture(const QString &command) const {
        QProcess p;
        p.start("sh", {"-lc", command});
        p.waitForFinished();
        return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
    }

    Q_INVOKABLE int run(const QString &command) const {
        return QProcess::execute("sh", {"-lc", command});
    }
};

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("emoji-picker");

    Sys sys;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("Sys", &sys);

    // Load QML from resource
    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}

#include "main.moc"
