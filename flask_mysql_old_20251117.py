from flask import Flask, render_template, request
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text
import os

# Try to load environment variables from .env file, but don't fail if not found
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

app = Flask(__name__)

# Use environment variable if available, otherwise use default connection string
database_url = os.getenv('DATABASE_URL', 'mysql+pymysql://minerho:P_ssw0rd@rm-uf6bbjfr09z01wl7jfo.mysql.rds.aliyuncs.com:3306/filelist')

app.config['SQLALCHEMY_DATABASE_URI'] = database_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

@app.route('/', methods=['GET', 'POST'])
def index():
    results = []
    columns = []
    page = request.args.get('page', 1, type=int)
    per_page = 20
    
    # 获取查询参数，优先从 form 获取，否则从 args 获取
    param1 = request.form.get('param1', '') or request.args.get('param1', '')
    param2 = request.form.get('param2', '') or request.args.get('param2', '')
    
    # 如果有查询参数，执行查询
    if param1 or param2 or 1:
        with db.engine.connect() as conn:
            # 首先获取总记录数
            count_sql = text(f"SELECT COUNT(*) FROM myfiles WHERE filename LIKE CONCAT('%', :param1, '%', :param2, '%')")
            total_count = conn.execute(count_sql, {'param1': param1, 'param2': param2}).scalar()
            
            # 计算总页数
            total_pages = (total_count + per_page - 1) // per_page
            
            # 添加 LIMIT 和 OFFSET 实现分页
            sql = text(f"SELECT * FROM myfiles WHERE filename LIKE CONCAT('%', :param1, '%', :param2, '%') LIMIT :limit OFFSET :offset")
            result = conn.execute(sql, {
                'param1': param1, 
                'param2': param2,
                'limit': per_page,
                'offset': (page - 1) * per_page
            })
            columns = result.keys()
            results = [dict(zip(columns, row)) for row in result.fetchall()]
            
            return render_template('index.html', 
                                 results=results, 
                                 columns=columns,
                                 page=page,
                                 total_pages=total_pages,
                                 param1=param1,
                                 param2=param2)
    
    return render_template('index.html', results=results, columns=columns, page=1, total_pages=1)

if __name__ == '__main__':
    # Only use this for development
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)