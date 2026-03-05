cmake_minimum_required(VERSION 3.16)
project(emoji_picker LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Critical for Q_OBJECT / moc
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)

qt_add_executable(emoji-picker
  main.cpp
  qml.qrc
)

target_link_libraries(emoji-picker PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick
)
