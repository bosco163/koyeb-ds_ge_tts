FROM python:3.10-slim

# 1. 安装基础工具
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    git \
    curl \
    gnupg \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 2. 安装 Node.js 18+ (Qwen2API 需要)
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
RUN apt-get update && apt-get install -y nodejs

# 3. 部署 Edge TTS (Python - 5050)
WORKDIR /app/tts
RUN git clone https://github.com/travisvn/openai-edge-tts.git .
RUN pip install --no-cache-dir -r requirements.txt

# 4. 部署 DeepSeek2API (Python - 5001)
WORKDIR /app/deepseek
RUN git clone https://github.com/iidamie/deepseek2api.git .
RUN pip install --no-cache-dir -r requirements.txt

# ==========================================
# 5. 部署 Qwen2API (修复：增加前端编译步骤)
# ==========================================
WORKDIR /app/qwen
RUN git clone https://github.com/Rfym21/Qwen2API.git .
# 5.1 安装后端依赖
RUN npm install

# 5.2 ⚠️ 关键修复：编译前端静态资源
WORKDIR /app/qwen/public
RUN npm install
RUN npm run build

# 5.3 回到项目根目录并处理权限
WORKDIR /app/qwen
RUN mkdir -p caches data logs && chmod -R 777 caches data logs

# 6. 配置 Nginx 和 Supervisor
WORKDIR /app
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENV PORT=8000
EXPOSE 8000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
