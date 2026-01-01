FROM python:3.10-slim

# 1. 安装基础工具 (Nginx, Supervisor, Git)
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    git \
    curl \
    gnupg \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# ===========================
# 2. 部署 Edge TTS (Python - 端口 5050)
# ===========================
WORKDIR /app/tts
RUN git clone https://github.com/travisvn/openai-edge-tts.git .
RUN pip install --no-cache-dir -r requirements.txt

# ===========================
# 3. 部署 DeepSeek2API (Python - 端口 5001)
# ===========================
WORKDIR /app/deepseek
RUN git clone https://github.com/iidamie/deepseek2api.git .
RUN pip install --no-cache-dir -r requirements.txt

# ===========================
# 4. 部署 Qwen3-Reverse (Python - 端口改为 3000)
# ===========================
WORKDIR /app/qwen
# 换成了你指定的新项目
RUN git clone https://github.com/wwwzhouhui/qwen3-reverse.git .
RUN pip install --no-cache-dir -r requirements.txt
# 创建日志和数据库目录，防止权限报错
RUN mkdir -p logs db && chmod 777 logs db

# ===========================
# 5. 配置 Nginx 和 Supervisor
# ===========================
WORKDIR /app
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 环境变量
ENV PORT=8000
EXPOSE 8000

# 启动
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
