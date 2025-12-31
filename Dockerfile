# 使用多阶段构建来获取 Go 环境，最终基于 Python 镜像
FROM golang:1.21 AS go-builder

# 最终镜像
FROM python:3.10-slim

# 1. 把 Go 搬运过来
COPY --from=go-builder /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"

# 2. 安装基础工具 和 Node.js
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    git \
    curl \
    gnupg \
    build-essential \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    && npm install -g yarn \
    && rm -rf /var/lib/apt/lists/*

# ===========================
# 3. 项目 A: Edge TTS (Python) -> 端口 5050
# ===========================
WORKDIR /app/tts
RUN git clone https://github.com/travisvn/openai-edge-tts.git .
RUN pip install --no-cache-dir -r requirements.txt

# ===========================
# 4. 项目 B: Gemini 逆向 (Go) -> 端口 3000
#    替代原来的 Doubao
# ===========================
WORKDIR /app/gemini
RUN git clone https://github.com/erxiansheng/gemininixiang.git .
# 编译 Go 项目为二进制文件，命名为 server
RUN go mod download
RUN go build -o server main.go

# ===========================
# 5. 项目 C: DeepSeek (Node.js) -> 端口 4000
#    新加的项目，映射到 /ds
# ===========================
WORKDIR /app/deepseek
RUN git clone https://github.com/iidamie/deepseek2api.git .
RUN npm install
# 这一步是为了防止端口冲突，虽然我们会在 env 里设置，但保险起见
# 如果源码里硬编码了端口，这里尝试替换一下（可选）
RUN grep -rl "3000" . | xargs sed -i 's/3000/4000/g' || true

# ===========================
# 6. 配置 Nginx 和 Supervisor
# ===========================
WORKDIR /app
COPY nginx.conf /etc/nginx/sites-available/default
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENV PORT=8000
EXPOSE 8000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
