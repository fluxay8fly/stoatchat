FROM node:20-slim AS builder

RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app

# 复制配置文件
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json .npmrc ./
COPY packages/ ./packages/

# 安装所有依赖
RUN pnpm install --frozen-lockfile

# 复制源码
COPY . .

# 执行构建：先构建依赖包，再构建前端主应用
RUN pnpm run build:deps
RUN pnpm --filter client run build

# 运行阶段
FROM nginx:stable-alpine
# 确保路径指向 client 的产物目录
COPY --from=builder /app/packages/client/dist /usr/share/nginx/html

RUN printf 'server {\n\
    listen 80;\n\
    location / {\n\
        root /usr/share/nginx/html;\n\
        index index.html index.htm;\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
