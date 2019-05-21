---

---



# 前期准备

- 查看此机器之前有无登陆过

  ```shell
  who /var/log/wtmp
  last
  ```

- 查看linux版本

  - centos

    ```shell
     lsb_release -a
    ```

  - 所有linux版本

    ```shell
    uname -a
    ```

  - RedHat,Centos

    ```shell
    cat /etc/redhat-release
    ```

- 更新原

  ```shell
  mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
  cd /etc/yum.repos.d/
  wget http://mirrors.aliyun.com/repo/Centos-7.repo
  mv Centos-7.repo CentOS-Base.repo
  yum makecache
  yum -y update
  ```

  

