# eks-study

## 목적

## 사전 준비
- 사전환경
    - Computer : mac m1
    - 환경 : Visual Code, Git
- tfenv 설치 및 테라폼 설치
- kubectl 설치
- aws-iam-authenticator
- AWS 사전 준비
    - [x] AWS 계정 생성, MFA 등록, 프로파일 등록
    - [x] ssh key 생성
    - [x] ecr 레포 준비 
- 샘플 앱 코드 빌드
    - [ ] backend-app 
        ```
            openjdk-11
        ```
    - [ ] frontend-app
        ```
            node v11
            package.json
        ```

## 아키텍처
- 

## To-Do
- [x] 기본 환경 셋팅 
- [x] backend-app 어플리케이션 빌드 및 띄워보기  
- [ ] frontend-app 어플리케이션 빌드 및 띄워보기
- [x] batch-app 어플리케이션 빌드 및 띄워보기
- [x] 기본 Nginx 및 Service 구동
- [ ] 기본 Nginx 및 Ingress-Controller 구동
- [ ] karpender 붙여보기
- [ ] ebpf 적용 및 networkpolicy 확인
- [ ] 이외 리소스 확인 및 정리

## 참고자료
- https://aws.github.io/aws-eks-best-practices/security/docs/
- https://archive.eksworkshop.com/010_introduction/eks/eks_high_architecture/
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/sec-group-reqs.html
- https://www.cloudforecast.io/blog/using-terraform-to-deploy-to-eks/
- https://aws.github.io/aws-eks-best-practices/reliability/docs/controlplane/