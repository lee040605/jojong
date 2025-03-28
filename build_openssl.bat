@echo off
REM Visual Studio 빌드 도구 환경 설정
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"

REM OpenSSL 소스 폴더로 이동
cd /d D:\openssl

REM Configure: 빌드 설정
perl Configure VC-WIN64A --prefix=D:\openssl-win64\install

REM Clean: 이전 빌드 내용 정리
nmake clean

REM Build: OpenSSL 빌드
nmake

REM Install: 설치
nmake install

REM 빌드 완료 후 일시 정지
pause
