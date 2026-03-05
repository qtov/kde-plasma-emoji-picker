#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QProcess>
#include <QFile>
#include <QTextStream>
#include <QTimer>
#include <QLocalServer>
#include <QLocalSocket>

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

static const char *SOCKET_NAME = "emoji-picker-ipc";

static bool sendCommand(const QString &cmd) {
    QLocalSocket s;
    s.connectToServer(SOCKET_NAME);
    if (!s.waitForConnected(50))
        return false;
    s.write(cmd.toUtf8());
    s.flush();
    s.waitForBytesWritten(50);
    s.disconnectFromServer();
    return true;
}

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("emoji-picker");

    const QStringList args = app.arguments();
    const bool wantToggle = args.contains("--toggle");
    const bool wantShow   = args.contains("--show");

    // If there is already an instance, just signal it and exit fast.
    if (wantToggle) {
        if (sendCommand("toggle")) return 0;
        // no server -> fall through and become the server
    }
    if (wantShow) {
        if (sendCommand("show")) return 0;
        // no server -> fall through and become the server
    }

    // Become the single-instance server.
    // Clean up stale socket (unclean exit).
    QLocalServer::removeServer(SOCKET_NAME);

    QLocalServer server;
    if (!server.listen(SOCKET_NAME)) {
        // If we can't listen, still run normally (rare), but you lose single-instance.
    }

    Sys sys;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("Sys", &sys);
    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    QObject *root = engine.rootObjects().first();

    auto showAndFocus = [root]() {
        // show + raise + focus search (QML function)
        QMetaObject::invokeMethod(root, "showAndFocus");
    };

    auto toggle = [root]() {
        bool vis = root->property("visible").toBool();
        if (vis) {
            root->setProperty("visible", false);
        } else {
            QMetaObject::invokeMethod(root, "showAndFocus");
        }
    };

    QObject::connect(&server, &QLocalServer::newConnection, [&]() {
        while (server.hasPendingConnections()) {
            QLocalSocket *c = server.nextPendingConnection();
            QObject::connect(c, &QLocalSocket::readyRead, [c, showAndFocus, toggle]() {
                const QString cmd = QString::fromUtf8(c->readAll()).trimmed();
                if (cmd == "show") showAndFocus();
                else if (cmd == "toggle") toggle();
                c->disconnectFromServer();
                c->deleteLater();
            });
        }
    });

    // If this invocation was a toggle/show but server didn’t exist, we want to show now.
    if (wantToggle || wantShow) {
        QTimer::singleShot(0, showAndFocus);
    }

    return app.exec();
}

#include "main.moc"
