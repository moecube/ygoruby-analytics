FROM ruby

# 安装 apt 依赖
RUN apt-get update
RUN apt-get install -y cron curl

# 安装 ruby 依赖
RUN bundle config --global frozen 1
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
COPY ./Gemfile /usr/src/app
COPY ./Gemfile.lock /usr/src/app
COPY . /usr/src/app
#RUN bundle install

# 配置计划任务
# 妈啊不会
#COPY ./Crontab /etc/cron.d/cron
#RUN chmod 0644 /etc/cron.d/cron
#RUN touch /usr/src/cron.log
#CMD cron && tail -f /usr/src/cron.log

# 启动
RUN ruby -X /usr/src/app
#RUN ruby /usr/src/app/main.rb