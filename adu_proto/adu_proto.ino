#include <Wire.h>
#include <GY80.h>
#include <Servo.h> // Servo 라이브러리 사용

// GY80 센서 객체 생성
GY80 gy80;

// ESC 객체 생성
Servo escFrontLeft, escFrontRight, escBackLeft, escBackRight;

// ESC 핀 설정
const int ESC_FRONT_LEFT_PIN = 3;
const int ESC_FRONT_RIGHT_PIN = 10;
const int ESC_BACK_LEFT_PIN = 11;
const int ESC_BACK_RIGHT_PIN = 9;

// RX7 수신기 핀 설정
const int RX_ELEV_PIN = 5;
const int RX_AIL_PIN = 4;
const int RX_THRO_PIN = 2;
const int RX_RUDD_PIN = 6;
const int RX_GEAR_AUX_PIN = 7;

// 기본 ESC 신호 (1000~2000)
const int THROTTLE_SIGNAL = 1500; // 기본 신호

void setup() {
  Serial.begin(9600);
  Wire.begin();

  // GY80 센서 초기화
  gy80.begin();
  Serial.println("GY80 initialized.");

  // ESC 초기화
  escFrontLeft.attach(ESC_FRONT_LEFT_PIN);
  escFrontRight.attach(ESC_FRONT_RIGHT_PIN);
  escBackLeft.attach(ESC_BACK_LEFT_PIN);
  escBackRight.attach(ESC_BACK_RIGHT_PIN);

  // RX7 핀 입력 모드 설정
  pinMode(RX_ELEV_PIN, INPUT);
  pinMode(RX_AIL_PIN, INPUT);
  pinMode(RX_THRO_PIN, INPUT);
  pinMode(RX_RUDD_PIN, INPUT);
  pinMode(RX_GEAR_AUX_PIN, INPUT);

  // 초기 ESC 신호 설정
  initializeESC();
}

void loop() {
  // RX7 신호 읽기
  int elevSignal = pulseIn(RX_ELEV_PIN, HIGH, 25000);
  int ailSignal = pulseIn(RX_AIL_PIN, HIGH, 25000);
  int throSignal = pulseIn(RX_THRO_PIN, HIGH, 25000);
  int ruddSignal = pulseIn(RX_RUDD_PIN, HIGH, 25000);
  int gearAuxSignal = pulseIn(RX_GEAR_AUX_PIN, HIGH, 25000);

  // 수신기 신호 디버깅 출력
  Serial.print("Elev: "); Serial.print(elevSignal);
  Serial.print(", Ail: "); Serial.print(ailSignal);
  Serial.print(", Thro: "); Serial.print(throSignal);
  Serial.print(", Rudd: "); Serial.print(ruddSignal);
  Serial.print(", Gear/Aux: "); Serial.println(gearAuxSignal);

  // 모든 모터를 2000 (최대 신호)로 5초간 회전
  writeESC(escFrontLeft, 2000);
  writeESC(escFrontRight, 2000);
  writeESC(escBackLeft, 2000);
  writeESC(escBackRight, 2000);
  delay(5000); // 5초 대기

  // 모든 모터를 정지 (1000) 상태로 3초 대기
  writeESC(escFrontLeft, 1000);
  writeESC(escFrontRight, 1000);
  writeESC(escBackLeft, 1000);
  writeESC(escBackRight, 1000);
  delay(3000); // 3초 대기
}

void initializeESC() {
  // ESC를 초기화 값으로 설정 (최소 신호)
  writeESC(escFrontLeft, 1000);
  writeESC(escFrontRight, 1000);
  writeESC(escBackLeft, 1000);
  writeESC(escBackRight, 1000);
  delay(3000); // ESC 초기화 대기
}

void writeESC(Servo &esc, int signal) {
  signal = constrain(signal, 1000, 2000); // 신호 제한
  esc.writeMicroseconds(signal); // Servo 객체를 통해 정확한 PWM 신호 전달
}
